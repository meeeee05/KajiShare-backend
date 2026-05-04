module Api
  module V1
    class NotificationsController < ApplicationController
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 100

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
        return DEFAULT_LIMIT if requested <= 0

        [requested, MAX_LIMIT].min
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
        return [] if current_user_group_ids.empty?

        Membership
          .includes(:user, :group)
          .where(group_id: current_user_group_ids)
          .where.not(user_id: current_user.id)
          .order(created_at: :desc)
          .limit(limit)
          .map do |membership|
            build_notification(
              key: "member_joined",
              record_id: membership.id,
              type: "member_joined",
              title: "新しいメンバーが参加しました",
              message: "#{membership.user.name}さんが#{membership.group.name}に参加しました",
              occurred_at: membership.created_at,
              group_id: membership.group_id
            )
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
            build_notification(
              key: "task_assigned",
              record_id: assignment.id,
              type: "task_assigned",
              title: "新規タスクが割り当てられました",
              message: "#{assignment.task.name}が割り当てられました",
              occurred_at: assignment.created_at,
              group_id: assignment.task.group_id,
              task_id: assignment.task_id,
              assignment_id: assignment.id
            )
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
            build_notification(
              key: "task_evaluated",
              record_id: evaluation.id,
              type: "task_evaluated",
              title: "タスクが評価されました",
              message: "#{evaluation.assignment.task.name}が#{evaluation.evaluator.name}さんに評価されました",
              occurred_at: evaluation.created_at,
              group_id: evaluation.assignment.task.group_id,
              task_id: evaluation.assignment.task_id,
              assignment_id: evaluation.assignment_id,
              evaluation_id: evaluation.id
            )
          end
      end

      # 現在のユーザーが所属するグループIDのリストをキャッシュ
      def current_user_group_ids
        @current_user_group_ids ||= current_user.memberships.where(active: true).pluck(:group_id)
      end

      # 通知1件分の共通フォーマットを作成
      def build_notification(key:, record_id:, type:, title:, message:, occurred_at:, **extra)
        {
          id: "#{key}_#{record_id}",
          type: type,
          title: title,
          message: message,
          occurred_at: occurred_at
        }.merge(extra)
      end
    end
  end
end
