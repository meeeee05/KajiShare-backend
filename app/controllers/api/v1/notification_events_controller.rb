module Api
  module V1
    class NotificationEventsController < ApplicationController
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 1000

      before_action :authenticate_user!

      # GET /api/v1/notifications
      def index
        limit = normalized_limit
        notifications = build_notifications(limit)
        latest_task_assigned_event_id = latest_task_assigned_event_id_for_current_user

        render json: {
          success: true,
          data: notification_response_data(notifications, latest_task_assigned_event_id)
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
        return task_assigned_notifications(limit) if task_assigned_only? || records_mode?

        items = notification_collections(limit).flatten

        items.sort_by { |item| item[:occurred_at] }.reverse.first(limit)
      end

      def notification_collections(limit)
        [
          group_join_notifications(limit),
          task_assigned_notifications(limit),
          task_evaluated_notifications(limit)
        ]
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
        task_assigned_scope
          .order(occurred_at: :desc, id: :desc)
          .limit(limit)
          .map do |event|
            build_notification(
              key: "task_assigned",
              record_id: event.id,
              type: "task_assigned",
              title: "新規タスクが割り当てられました",
              message: task_assigned_message(event),
              occurred_at: event.occurred_at,
              group_id: event.group_id,
              task_id: event.task_id,
              assignment_id: event.assignment_id
            )
          end
      end

      # 自分が実施したタスクが評価された通知
      def task_assigned_scope
        scope = NotificationEvent.where(event_type: "task_assigned", recipient_user_id: current_user.id)
        return scope unless normalized_since_id.present?

        scope.where("id > ?", normalized_since_id)
      end

      # タスク割り当て通知のメッセージを生成
      def task_assigned_message(event)
        event.payload["message"].presence || "タスクが割り当てられました"
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

      # since_idクエリパラメータを正規化して数値を返す。無効な値の場合はnilを返す
      def normalized_since_id
        raw = params[:since_id]
        return nil if raw.blank?

        # フロントが "task_assigned_123" を渡しても末尾の数値を解釈できるようにする
        token = raw.to_s
        numeric = token[/\d+\z/]&.to_i
        return nil if numeric.blank? || numeric <= 0

        numeric
      end

      # タスク割り当て通知のみを取得
      def task_assigned_only?
        value = params[:type] || params[:types] || params[:only]
        value.to_s == "task_assigned"
      end

      def records_mode?
        ActiveModel::Type::Boolean.new.cast(params[:for_records])
      end

      # 現在のユーザーに関連する最新のタスク割り当て通知イベントIDを取得
      def latest_task_assigned_event_id_for_current_user
        NotificationEvent
          .where(event_type: "task_assigned", recipient_user_id: current_user.id)
          .maximum(:id)
      end

      # 通知APIのレスポンスデータを構築
      def notification_response_data(notifications, latest_task_assigned_event_id)
        {
          viewer_user_id: current_user.id,
          viewer_google_sub: current_user.google_sub,
          mode: records_mode? ? "records" : "default",
          notifications: notifications,
          total: notifications.size,
          latest_task_assigned_event_id: latest_task_assigned_event_id,
          server_time: Time.current.iso8601
        }
      end
    end
  end
end
