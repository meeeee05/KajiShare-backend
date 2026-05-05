# app/controllers/api/v1/assignments_controller.rb
module Api
  module V1
    class AssignmentsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_task, only: [:create]
      before_action :set_task_for_index, only: [:index], if: -> { params[:task_id].present? }
      before_action :set_assignment, only: [:show, :update, :destroy]
      before_action :validate_permission  
      
      # GET /api/v1/tasks/:task_id/assignments
      def index
        assignments = if @task
                        @task.assignments.order(:due_date)
                      elsif params[:group_id].present?
                        Assignment.joins(:task)
                                  .where(tasks: { group_id: params[:group_id] })
                                  .includes(:task, membership: :user)
                                  .order(:due_date)
                      else
        return handle_unprocessable_entity(["group_id または task_id が必要です"])
        end

        render json: assignments, each_serializer: AssignmentSerializer
      end

      # GET /api/v1/assignments/:id
      def show
        render_assignment_success(@assignment)
      end

      # POST /api/v1/tasks/:task_id/assignments - Member権限以上が必要
      def create
        begin
          assignment = @task.assignments.build(assignment_params)

          # 割り振り先が指定されていればそのメンバーへ、未指定なら作成者自身へ割り当てる
          target_membership = resolve_target_membership_for_create
          if target_membership.nil?
            return handle_unprocessable_entity(["割り当て先メンバーが見つかりません"])
          end
          assignment.membership_id = target_membership.id
          assignment.assigned_to_id = target_membership.user_id
          assignment.assigned_by_id = current_user.id
          assignment.assigned_at = Time.current

          if assignment.save
            Rails.logger.info "Assignment created: (ID: #{assignment.id}) for Task '#{@task.name}' by user #{current_user.name}"
            render_assignment_success(assignment, :created)
          else
            handle_unprocessable_entity(assignment.errors.full_messages)
          end
        rescue ActionController::ParameterMissing
          raise
        rescue StandardError => e
          handle_internal_error("Failed to create assignment: #{e.message}")
        end
      end

      # PATCH/PUT /api/v1/assignments/:id - Member権限以上が必要
      def update
        begin
          target_membership = resolve_target_membership_for_update(@assignment.task.group_id)
          if target_membership
            @assignment.membership_id = target_membership.id
            @assignment.assigned_to_id = target_membership.user_id
            # 割り振り操作が行われたときは、同一担当者でも通知イベント用に時刻を更新する
            @assignment.assigned_by_id = current_user.id
            @assignment.assigned_at = Time.current
          end

          if @assignment.update(assignment_params)
            Rails.logger.info "Assignment updated: (ID: #{@assignment.id}) for Task '#{@assignment.task.name}' by user #{current_user.name}"
            render_assignment_success(@assignment)
          else
            handle_unprocessable_entity(@assignment.errors.full_messages)
          end
        rescue ActionController::ParameterMissing
          raise
        rescue StandardError => e
          handle_internal_error("Failed to update assignment: #{e.message}")
        end
      end

      # DELETE /api/v1/assignments/:id - Admin権限が必要
      def destroy
        begin
          ActiveRecord::Base.transaction do
            Rails.logger.info "Deleting assignment (ID: #{@assignment.id}) from Task '#{@assignment.task.name}' by admin user #{current_user.name}"
            
            @assignment.destroy!
            
            render json: { 
              message: "Assignment has been successfully deleted",
              deleted_at: Time.current 
            }, status: :ok
          end
        rescue StandardError => e
          handle_internal_error("Failed to delete assignment: #{e.message}")
        end
      end

      private

      # タスクをセット（indexとcreateで使用）→ タスクが見つからない場合は404エラー
      def set_task
        @task = Task.find(params[:task_id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("ID: #{params[:task_id]} のタスクが見つかりません")
      end

      # タスクをセット → タスクが見つからない場合は404エラー
      def set_task_for_index
        @task = Task.find(params[:task_id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("ID: #{params[:task_id]} のタスクが見つかりません")
      end

      # アサインメントをセット（show, update, destroyで使用）→ アサインメントが見つからない場合は404エラー
      def set_assignment
        @assignment = Assignment.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("ID: #{params[:id]} の担当が見つかりません")
      end
      
      # Strong Parameters(以下パラメータを受け入れ)
      def assignment_params
        params.require(:assignment).permit(:due_date, :completed_date, :comment, :status)
      end

      # create時の割り当て先メンバーシップを解決
      def resolve_target_membership_for_create
        requested_membership_id = params.dig(:assignment, :membership_id)
        if requested_membership_id.present?
          return Membership.find_by(id: requested_membership_id, group_id: @task.group_id, active: true)
        end

        requested_user_id = params.dig(:assignment, :assigned_to_id) || params.dig(:assignment, :user_id)
        if requested_user_id.present?
          return Membership.find_by(user_id: requested_user_id, group_id: @task.group_id, active: true)
        end

        get_current_user_membership(@task.group_id)
      end

      #　更新時の割り当て先変更
      def resolve_target_membership_for_update(group_id)
        requested_membership_id = params.dig(:assignment, :membership_id)
        if requested_membership_id.present?
          return Membership.find_by(id: requested_membership_id, group_id: group_id, active: true)
        end

        requested_user_id = params.dig(:assignment, :assigned_to_id) || params.dig(:assignment, :user_id)
        if requested_user_id.present?
          return Membership.find_by(user_id: requested_user_id, group_id: group_id, active: true)
        end

        nil
      end
      
      # 権限チェック
      def validate_permission
        group_id, required_role = case action_name
        when 'index'
          [@task&.group_id || params[:group_id], 'member']
        when 'create'
          [@task.group_id, 'member']
        when 'show', 'update'
          [@assignment.task.group_id, 'member']
        when 'destroy'
          [@assignment.task.group_id, 'admin']
        end

        membership = get_current_user_membership(group_id)
        validate_membership(membership, required_role)
      end

      # 権限取得とエラーハンドリング
      def get_current_user_membership(group_id)
        current_user.memberships.find_by(group_id: group_id, active: true)
      end

      # 権限検証
      def validate_membership(membership, required_role = 'member')
        return handle_forbidden("このグループのメンバーではありません") if membership.nil?
        
        if required_role == 'admin' && !membership.admin?
          return handle_forbidden("この操作には管理者権限が必要です")
        end
      end

      # 共通メソッド：アサインメント情報のJSONレスポンスを生成
      def render_assignment_success(assignment, status = :ok)
        render json: assignment, serializer: AssignmentSerializer, status: status
      end
    end
  end
end