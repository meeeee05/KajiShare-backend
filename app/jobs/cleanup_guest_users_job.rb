class CleanupGuestUsersJob < ApplicationJob
  queue_as :default

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

  def expired_guest_users
    User.where(account_type: "guest").where("created_at <= ?", EXPIRATION_WINDOW.ago)
  end

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
