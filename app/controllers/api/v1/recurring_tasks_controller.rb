module Api
  module V1
    class RecurringTasksController < ApplicationController
      include GroupMembershipValidation

      before_action :authenticate_user!
      before_action :set_group, only: [:index, :create]
      before_action :set_recurring_task, only: [:show, :update, :destroy]
      before_action :check_member_permission, only: [:index, :show]
      before_action :check_admin_permission, only: [:create, :update, :destroy]

      # GET /api/v1/groups/:group_id/recurring_tasks
      def index
        recurring_tasks = @group.recurring_tasks.order(:id)
        render json: recurring_tasks, each_serializer: RecurringTaskSerializer
      end

      # GET /api/v1/recurring_tasks/:id
      def show
        render_recurring_task_success(@recurring_task)
      end

      # POST /api/v1/groups/:group_id/recurring_tasks
      def create
        recurring_task = @group.recurring_tasks.new(recurring_task_params)
        recurring_task.created_by_id = current_user.id

        # DBに定期タスク設定を保存
        if recurring_task.save
          Rails.logger.info "Recurring task created: '#{recurring_task.name}' in Group '#{@group.name}' by user #{current_user.name}"
          render_recurring_task_success(recurring_task, :created)
        else
          handle_unprocessable_entity(recurring_task.errors.full_messages)
        end
      rescue StandardError => e
        handle_internal_error("Failed to create recurring task: #{e.message}")
      end

      # PATCH/PUT /api/v1/recurring_tasks/:id
      def update
        if @recurring_task.update(recurring_task_params)
          Rails.logger.info "Recurring task updated: '#{@recurring_task.name}' (ID: #{@recurring_task.id}) by user #{current_user.name}"
          render_recurring_task_success(@recurring_task)
        else
          handle_unprocessable_entity(@recurring_task.errors.full_messages)
        end
      rescue StandardError => e
        handle_internal_error("Failed to update recurring task: #{e.message}")
      end

      # DELETE /api/v1/recurring_tasks/:id
      def destroy
        @recurring_task.destroy!
        render json: {
          message: "Recurring task has been successfully deleted",
          deleted_at: Time.current
        }, status: :ok
      rescue StandardError => e
        handle_internal_error("Failed to delete recurring task: #{e.message}")
      end

      private

      # グループをセット,グループが見つからない場合は404エラー
      def set_group
        @group = Group.find(params[:group_id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("ID: #{params[:group_id]} のグループが見つかりません")
      end

      # 定期タスクをセット,定期タスクが見つからない場合は404エラー
      def set_recurring_task
        @recurring_task = RecurringTask.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("ID: #{params[:id]} の定期タスクが見つかりません")
      end

      # 定期タスクのパラメータ
      def recurring_task_params
        params.require(:recurring_task).permit(
          :name,
          :description,
          :point,
          :schedule_type,
          :day_of_week,
          :starts_on,
          :active
        )
      end

      # 定期タスクの成功レスポンスを共通化
      def render_recurring_task_success(recurring_task, status = :ok)
        render json: recurring_task, serializer: RecurringTaskSerializer, status: status
      end

      # グループIDを取得
      def get_group_id_for_action
        case action_name
        when "index", "create"
          @group.id
        when "show", "update", "destroy"
          @recurring_task.group_id
        end
      end

      # 権限チェック
      def check_member_permission
        membership = validate_group_membership_for_action
        return unless membership
      end

      # 管理者権限チェック
      def check_admin_permission
        membership = validate_group_membership_for_action
        return unless membership

        return handle_forbidden("この操作には管理者権限が必要です") unless membership.admin?
      end

      # グループメンバーシップ情報の取得
      def validate_group_membership_for_action
        group_id = get_group_id_for_action
        membership = current_user_membership(group_id)
        validate_membership(membership)
      end
    end
  end
end
