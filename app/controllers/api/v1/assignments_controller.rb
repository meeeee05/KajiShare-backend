# app/controllers/api/v1/assignments_controller.rb

module Api
  module V1
    class AssignmentsController < ApplicationController
      before_action :set_task, only: [:index, :create]
      before_action :set_assignment, only: [:show, :update, :destroy]
      before_action :authenticate_user!, only: [:create, :update, :destroy]
      before_action :check_member_permission, only: [:create, :update]  # 作成・更新はMember権限以上
      before_action :check_admin_permission, only: [:destroy]  # 削除はAdmin権限のみ

      # GET /api/v1/tasks/:task_id/assignments
      def index
        assignments = @task.assignments
        render json: assignments
      end

      # POST /api/v1/tasks/:task_id/assignments - Member権限以上が必要
      def create
        assignment = @task.assignments.build(assignment_params)
        
        # 現在のユーザーのmembership_idを自動設定
        membership = Membership.find_by(user_id: current_user.id, group_id: @task.group_id)
        assignment.membership_id = membership.id if membership

        if assignment.save
          render json: assignment, status: :created
        else
          render json: { errors: assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/assignments/:id
      def show
        render json: @assignment
      end

      # PATCH/PUT /api/v1/assignments/:id - Member権限以上が必要
      def update
        if @assignment.update(assignment_params)
          render json: @assignment
        else
          render json: { errors: @assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/assignments/:id - Admin権限が必要
      def destroy
        begin
          # トランザクション内で安全に削除
          ActiveRecord::Base.transaction do
            # 削除ログ記録
            Rails.logger.info "Deleting assignment (ID: #{@assignment.id}) from Task '#{@assignment.task.name}' by admin user #{current_user.name}"
            
            # アサインメントを削除（dependent: :destroyにより関連データも自動削除）
            @assignment.destroy!
            
            render json: { 
              message: "Assignment has been successfully deleted",
              deleted_at: Time.current 
            }, status: :ok
          end
        rescue => e
          Rails.logger.error "Failed to delete assignment: #{e.message}"
          render json: { error: "Failed to delete assignment: #{e.message}" }, status: :unprocessable_entity
        end
      end

      private

      def set_task
        @task = Task.find(params[:task_id])
      end

      def set_assignment
        @assignment = Assignment.find(params[:id])
      end

      def assignment_params
        params.require(:assignment).permit(
          :assigned_to_id,
          :assigned_by_id,
          :due_date,
          :completed_date,
          :comment
        )
      end

      # Member権限チェック：指定されたグループのメンバー（admin or member）のみ操作可能
      def check_member_permission
        # group_idの取得（新規作成時はタスクから、更新時は既存レコードから）
        group_id = action_name == 'create' ? @task.group_id : @assignment.task.group_id
        
        membership = Membership.find_by(user_id: current_user.id, group_id: group_id)

        # メンバー存在チェック
        if membership.nil?
          render json: { error: "You are not a member of this group" }, status: :forbidden
          return
        end

        # アクティブメンバーチェック
        unless membership.active?
          render json: { error: "Your membership is not active" }, status: :forbidden
        end
      end

      # Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        # group_idの取得（削除時は既存レコードから）
        group_id = @assignment.task.group_id
        
        membership = Membership.find_by(user_id: current_user.id, group_id: group_id)

        # メンバー存在チェック
        if membership.nil?
          render json: { error: "You are not a member of this group" }, status: :forbidden
          return
        end

        # Admin権限チェック
        if membership.role != "admin"
          render json: { error: "You are not allowed to perform this action. Admin permission required." }, status: :forbidden
        end
      end
    end
  end
end