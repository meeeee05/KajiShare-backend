class Assignment < ApplicationRecord

  #model関連付け
  belongs_to :task
  belongs_to :membership
  has_many :evaluations, dependent: :destroy

  # ステータスを管理
  enum :status, {
    pending: "pending",
    in_progress: "in_progress", 
    completed: "completed"
  }

  # バリデーション（フォーマットチェック）
  validates :task_id, presence: true
  validates :membership_id, presence: true
  validates :status, presence: true
  validate :completed_date_after_due_date

  # completed のときは completed_date が必須
  validates :completed_date, presence: true, if: :completed?

  # 同じタスクを同じ人に二重で割り当てない
  validates :task_id, uniqueness: { scope: :membership_id }

  # completed_dateの状態に応じてstatusを自動更新（コールバック = 自動更新）
  before_save :auto_update_status_based_on_completed_date

  # コールバック
  before_validation :sync_status_with_completed_date

  private

  # completed_dateの状態に基づいてstatusを自動更新
  def auto_update_status_based_on_completed_date
    if completed_date.present?
      # completed_dateが設定されている場合は自動的にcompletedにする
      self.status = "completed"
    elsif completed_date.blank? && status == "completed"
      # completed_dateがクリアされて、statusがcompletedの場合はpendingに戻す
      self.status = "pending"
    end
  end

  # completed_date は due_date より前にならない
  def completed_date_after_due_date
    return if completed_date.blank? || due_date.blank?

    if completed_date < due_date
      errors.add(:completed_date, "は期限日以降である必要があります")
    end
  end
end

  # completed_date と status の整合性を保つ
  def sync_status_with_completed_date
    if completed_date.present?
      self.status = "completed"
    elsif status.blank?
      self.status = "pending"
    end
  end
end