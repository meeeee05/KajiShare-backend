# app/controllers/api/v1/assignments_controller.rb
module Api
  module V1
    class AssignmentsController < ApplicationController
      before_action :set_task, only: [:index, :create]
      before_action :set_assignment, only: [:show, :update, :destroy]
      before_action :authenticate_user!  
      # 参照・作成・更新はMember権限以上
      before_action :check_member_permission, only: [:index, :show, :create, :update]  
      # 削除はAdmin権限のみ
      before_action :check_admin_permission, only: [:destroy]  
      
      # GET /api/v1/tasks/:task_id/assignments
      # assignmentsに入ってきた情報全てをJSON形式で返す
      def index
        assignments = @task.assignments
        render json: assignments, each_serializer: AssignmentSerializer
      end

      # GET /api/v1/assignments/:id
      # 特定のassignmentをJSON形式で返す
      def show
        render_assignment_success(@assignment)
      end


      # POST /api/v1/tasks/:task_id/assignments - Member権限以上が必要
      # 新しいAssignmentを作成して保存
      def create
        #オブジェクトの作成
        assignment = @task.assignments.build(assignment_params)
        
        #現在のユーザーのmembership_idを自動設定、整合性確保
        membership = current_user_membership(@task.group_id)
        assignment.membership_id = membership.id if membership

        if assignment.save
          Rails.logger.info "Assignment created: (ID: #{assignment.id}) for Task '#{@task.name}' by user #{current_user.name}"
          render_assignment_success(assignment, :created)
        else
          handle_unprocessable_entity(assignment.errors.full_messages)
        end
      end

      # PATCH/PUT /api/v1/assignments/:id - Member権限以上が必要
      def update
        begin
          if @assignment.update(assignment_params)
            Rails.logger.info "Assignment updated: (ID: #{@assignment.id}) for Task '#{@assignment.task.name}' by user #{current_user.name}"
            render_assignment_success(@assignment)
          else
            handle_unprocessable_entity(@assignment.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to update assignment: #{e.message}")
        end
      end

      # DELETE /api/v1/assignments/:id - Admin権限が必要
      def destroy
        begin
          #トランザクション内で安全に削除
          ActiveRecord::Base.transaction do
            # 削除ログ記録
            Rails.logger.info "Deleting assignment (ID: #{@assignment.id}) from Task '#{@assignment.task.name}' by admin user #{current_user.name}"
            
            #アサインメントを削除（関連データも削除）
            @assignment.destroy!
            
            render json: { 
              message: "Assignment has been successfully deleted",
              deleted_at: Time.current 
            }, status: :ok
          end
        rescue => e
          Rails.logger.error "Failed to delete assignment: #{e.message}"
          handle_internal_error(e)
        end
      end

      private

      # 該当するtaskを取得
      def set_task
        @task = Task.find(params[:task_id])
      rescue ActiveRecord::RecordNotFound => e
        handle_not_found("Task with ID #{params[:task_id]} not found")
      end

      # 該当するassignmentを取得
      def set_assignment
        @assignment = Assignment.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        handle_not_found("Assignment with ID #{params[:id]} not found")
      end
      
      # Strong Parameters(以下パラメータを受け入れ)
      def assignment_params
        params.require(:assignment).permit(
            :due_date,
            :completed_date,
            :comment
            )
        end
        
      # 現在のユーザーのメンバーシップ取得
      def current_user_membership(group_id)
        Membership.find_by(user_id: current_user.id, group_id: group_id)
      end

      # nilの場合や非アクティブの場合に403エラー
      def validate_membership(membership)
        return handle_forbidden("You are not a member of this group") if membership.nil?
        return handle_forbidden("Your membership is not active") unless membership.active?
        membership
      end

      # 権限チェック：指定されたグループのmember以上の権限のみ操作可能
      def check_member_permission
        group_id = get_group_id_for_action
        membership = current_user_membership(group_id)
        validate_membership(membership)
      end

      # Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        group_id = @assignment.task.group_id
        membership = current_user_membership(group_id)
        validate_membership(membership)

        return handle_forbidden("You are not allowed to perform this action. Admin permission required.") unless membership.admin?
      end

      # アクション別のgroup_id取得
      def get_group_id_for_action
        case action_name
        when 'index', 'create'
          @task.group_id
        when 'show', 'update'
          @assignment.task.group_id
        end
      end

      # 共通メソッド：アサインメント情報のJSONレスポンスを生成
      def render_assignment_success(assignment, status = :ok)
        render json: assignment, serializer: AssignmentSerializer, status: status
      end
    end
  end
end