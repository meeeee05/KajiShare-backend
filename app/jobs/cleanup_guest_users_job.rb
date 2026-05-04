class CleanupGuestUsersJob < ActiveJob::Base
  queue_as :default

  GUEST_ACCOUNT_TYPE = "guest"
  EXPIRATION_WINDOW = 1.hour

  # 1時間経過したゲストユーザーと、その作成データを削除
  def perform
    expired_guest_users.find_each do |user|
      cleanup_guest_user!(user)
    rescue StandardError => e
      Rails.logger.error "Guest cleanup failed for user_id=#{user.id}: #{e.message}"
    end
  end

  private

  # 期限切れのゲストユーザーを取得
  def expired_guest_users
    User.where(account_type: GUEST_ACCOUNT_TYPE).where("created_at <= ?", expiration_threshold)
  end

  # 期限切れの基準日時を計算
  def expiration_threshold
    EXPIRATION_WINDOW.ago
  end

  # ゲストユーザーと関連データを安全に削除
  def cleanup_guest_user!(user)
    ActiveRecord::Base.transaction do
      created_group_ids = user.created_groups.pluck(:id)

      # ゲスト作成グループは関連データごと削除
      user.created_groups.find_each(&:destroy!)

      # 上で消えなかった「ゲスト作成の定期タスク」も削除
      user.created_recurring_tasks.where.not(group_id: created_group_ids).find_each(&:destroy!)

      user.destroy!
    end

    Rails.logger.info "Guest cleanup completed for user_id=#{user.id}"
  end
end
