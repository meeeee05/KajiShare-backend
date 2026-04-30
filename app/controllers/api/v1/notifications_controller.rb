module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/notifications
      def index
        limit = normalized_limit
        notifications = build_notifications(limit)

        render json: {
          success: true,
          data: {
            notifications: notifications,
            total: notifications.size
          }
        }
      end

      private

      # クエリパラメータのlimitを正規化
      def normalized_limit
        requested = params[:limit].to_i
        return 50 if requested <= 0

        [requested, 100].min
      end

      # 現在のユーザーに関連する最新の通知を取得
      def build_notifications(limit)
        items = []
        items.concat(group_join_notifications(limit))
        items.concat(task_assigned_notifications(limit))
        items.concat(task_evaluated_notifications(limit))

        items.sort_by { |item| item[:occurred_at] }.reverse.first(limit)
      end

      # 自分が所属するグループに、新しいユーザーが参加した通知
      def group_join_notifications(limit)
        user_group_ids = current_user.memberships.where(active: true).pluck(:group_id)
        return [] if user_group_ids.empty?

        Membership
          .includes(:user, :group)
          .where(group_id: user_group_ids)
          .where.not(user_id: current_user.id)
          .order(created_at: :desc)
          .limit(limit)
          .map do |membership|
            {
              id: "member_joined_#{membership.id}",
              type: "member_joined",
              title: "新しいメンバーが参加しました",
              message: "#{membership.user.name}さんが#{membership.group.name}に参加しました",
              occurred_at: membership.created_at,
              group_id: membership.group_id
            }
          end
      end

      # 自分にタスクが割り当てられた通知
      def task_assigned_notifications(limit)
        Assignment
          .includes(:task, membership: :group)
          .joins(:membership)
          .where(memberships: { user_id: current_user.id })
          .order(created_at: :desc)
          .limit(limit)
          .map do |assignment|
            {
              id: "task_assigned_#{assignment.id}",
              type: "task_assigned",
              title: "新規タスクが割り当てられました",
              message: "#{assignment.task.name}が割り当てられました",
              occurred_at: assignment.created_at,
              group_id: assignment.task.group_id,
              task_id: assignment.task_id,
              assignment_id: assignment.id
            }
          end
      end

      # 自分が実施したタスクが評価された通知
      def task_evaluated_notifications(limit)
        Evaluation
          .includes(:evaluator, assignment: [:task, :membership])
          .joins(assignment: :membership)
          .where(memberships: { user_id: current_user.id })
          .where.not(evaluator_id: current_user.id)
          .order(created_at: :desc)
          .limit(limit)
          .map do |evaluation|
            {
              id: "task_evaluated_#{evaluation.id}",
              type: "task_evaluated",
              title: "タスクが評価されました",
              message: "#{evaluation.assignment.task.name}が#{evaluation.evaluator.name}さんに評価されました",
              occurred_at: evaluation.created_at,
              group_id: evaluation.assignment.task.group_id,
              task_id: evaluation.assignment.task_id,
              assignment_id: evaluation.assignment_id,
              evaluation_id: evaluation.id
            }
          end
      end
    end
  end
end
