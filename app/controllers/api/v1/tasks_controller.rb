module Api
  module V1
    class TasksController < ApplicationController
      before_action :set_group, only: [:create]  # createのみgroup必須
      before_action :set_task, only: [:show, :update, :destroy]
      before_action :authenticate_user!, only: [:create, :update, :destroy]
      before_action :check_member_permission, only: [:create, :update]  # 作成・更新はMember権限以上
      before_action :check_admin_permission, only: [:destroy]  # 削除はAdmin権限のみ

      # GET /api/v1/tasks - 全タスク一覧
      def index
        if params[:group_id].present?
          # グループ内のタスク一覧
          @group = Group.find(params[:group_id])
          tasks = @group.tasks
        else
          # 全タスク一覧
          tasks = Task.all
        end
        render json: tasks
      end

      # POST /api/v1/groups/:group_id/tasks - Member権限以上が必要
      def create
        task = @group.tasks.new(task_params)
        if task.save
          render json: task, status: :created
        else
          render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/tasks/:id
      def show
        render json: @task
      end

      # PUT/PATCH /api/v1/tasks/:id - Member権限以上が必要
      def update
        if @task.update(task_params)
          render json: @task
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tasks/:id - Admin権限が必要
      def destroy
        begin
          # トランザクション内で安全に削除
          ActiveRecord::Base.transaction do
            # 削除ログ記録
            Rails.logger.info "Deleting task '#{@task.name}' (ID: #{@task.id}) from Group '#{@task.group.name}' by admin user #{current_user.name}"
            
            # タスクを削除（dependent: :destroyにより関連データも自動削除）
            @task.destroy!
            
            render json: { 
              message: "Task '#{@task.name}' has been successfully deleted",
              deleted_at: Time.current 
            }, status: :ok
          end
        rescue => e
          Rails.logger.error "Failed to delete task: #{e.message}"
          render json: { error: "Failed to delete task: #{e.message}" }, status: :unprocessable_entity
        end
      end

      private

      def set_group
        @group = Group.find(params[:group_id])
      end

      def set_task
        @task = Task.find(params[:id])
      end

      def task_params
        params.require(:task).permit(:name, :description, :point)
      end

      #Member権限チェック：指定されたグループのメンバー（admin or member）のみ操作可能
      def check_member_permission
        #group_idの取得（新規作成時はパラメータから、更新時は既存レコードから）
        group_id = action_name == 'create' ? @group.id : @task.group_id
        
        membership = Membership.find_by(user_id: current_user.id, group_id: group_id)

        #メンバー存在チェック
        if membership.nil?
          render json: { error: "You are not a member of this group" }, status: :forbidden
          return
        end

        #アクティブメンバーチェック
        unless membership.active?
          render json: { error: "Your membership is not active" }, status: :forbidden
        end
      end

      # Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        # group_idの取得（削除時は既存レコードから）
        group_id = @task.group_id
        
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