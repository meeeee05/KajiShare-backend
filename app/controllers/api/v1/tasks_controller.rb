module Api
  module V1
    class TasksController < ApplicationController
      include GroupMembershipValidation

      before_action :set_group, only: [:index, :create]  # index、createでgroup必須
      before_action :set_task, only: [:show, :update, :destroy]
      before_action :authenticate_user!  # 全アクションで認証必須
      before_action :check_member_permission, only: [:index, :show, :create, :update, :destroy]  # 参照・作成・更新・削除はMember権限以上

      # GET /api/v1/groups/:group_id/tasks - グループメンバーのみアクセス可能（一覧表示）
      def index
        #グループ内のタスク一覧（メンバーシップチェック済み）
        tasks = @group.tasks
        tasks = filter_tasks_by_status(tasks)
        render json: tasks, each_serializer: TaskSerializer
      end

      # GET /api/v1/tasks/:id（詳細表示） - グループメンバーのみアクセス可能
      def show
        render_task_success(@task)
      end

      # POST /api/v1/groups/:group_id/tasks - Member権限以上が必要
      def create
        begin
          task = @group.tasks.new(task_params)
          if task.save
            Rails.logger.info "Task created: '#{task.name}' in Group '#{@group.name}' by user #{current_user.name}"
            render_task_success(task, :created)
          else
            handle_unprocessable_entity(task.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to create task: #{e.message}")
        end
      end

      # PUT/PATCH /api/v1/tasks/:id - Member権限以上が必要
      def update
        begin
          if @task.update(task_params)
            Rails.logger.info "Task updated: '#{@task.name}' in Group '#{@task.group.name}' by user #{current_user.name}"
            render_task_success(@task)
          else
            handle_unprocessable_entity(@task.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to update task: #{e.message}")
        end
      end

      # DELETE /api/v1/tasks/:id - Member権限以上が必要
      def destroy
        begin
          #トランザクション内で安全に削除
          ActiveRecord::Base.transaction do
            # 削除ログ記録
            Rails.logger.info "Deleting task '#{@task.name}' (ID: #{@task.id}) from Group '#{@task.group.name}' by user #{current_user.name}"
            
            #タスクを削除（dependent: :destroyにより関連データも自動削除）
            @task.destroy!
            
            render json: { 
              message: "Task '#{@task.name}' has been successfully deleted",
              deleted_at: Time.current 
            }, status: :ok
          end
        rescue => e
          Rails.logger.error "Failed to delete task: #{e.message}"
          handle_internal_error("Failed to delete task: #{e.message}")
        end
      end

      private

      def set_group
        @group = Group.find(params[:group_id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("ID: #{params[:group_id]} のグループが見つかりません")
      end

      def set_task
        @task = Task.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("ID: #{params[:id]} のタスクが見つかりません")
      end

      # Strong Parameters：タスク作成・更新用(ユーザーが入力すべき3つの項目以外は一切受け取らない)
      def task_params
        params.require(:task).permit(:name, :description, :point)
      end

      # 共通メソッド：指定されたグループに対するユーザーのメンバーシップを取得
      def current_user_membership(group_id)
        Membership.find_by(user_id: current_user.id, group_id: group_id)
      end

      # 共通メソッド：タスク情報のJSONレスポンスを生成
      def render_task_success(task, status = :ok)
        render json: task, serializer: TaskSerializer, status: status
      end

      # クエリパラメータに応じてタスクを絞り込む
      # - completed: 全assignmentがcompletedのタスクのみ
      # - incomplete: completed以外のタスク
      def filter_tasks_by_status(tasks)
        case params[:status]
        when 'completed'
          tasks.completed
        when 'incomplete'
          tasks.incomplete
        else
          tasks
        end
      end

      # グループIDを取得するヘルパーメソッド（権限チェック）
      def get_group_id_for_action
        case action_name
        when 'index', 'create'
          @group.id
        when 'show', 'update', 'destroy'
          @task.group_id
        end
      end

      #Member権限チェック：指定されたグループのmember権限以上のみ操作可能
      def check_member_permission
        validate_group_membership_for_action
      end

      #Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        membership = validate_group_membership_for_action
        return unless membership

        return handle_forbidden("この操作には管理者権限が必要です") unless membership.admin?
      end

      # アクションに応じた権限の検証
      def validate_group_membership_for_action
        group_id = get_group_id_for_action
        membership = current_user_membership(group_id)
        validate_membership(membership)
      end
    end
  end
end