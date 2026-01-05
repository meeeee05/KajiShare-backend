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

  # バリデーション
  validates :task_id, :membership_id, :status, presence: true
  validates :task_id, uniqueness: { scope: :membership_id }

  # completed のときは completed_date 必須
  validates :completed_date, presence: true, if: :completed?
  validate :completed_date_after_due_date

  # コールバック - ステータスと完了日の整合性を自動調整
  before_validation :sync_status_with_completed_date

  private

  def completed_date_after_due_date
    return unless completed_date.present? && due_date.present? && completed_date < due_date
    errors.add(:completed_date, "は期限日以降である必要があります")
  end

  def sync_status_with_completed_date
    self.status = completed_date.present? ? "completed" : (status.blank? ? "pending" : status)
  end
end