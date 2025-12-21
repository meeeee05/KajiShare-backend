class Assignment < ApplicationRecord

  #model関連付け
  belongs_to :task
  belongs_to :membership
  has_many :evaluations, dependent: :destroy

  # =====================
  # Enum
  # =====================
  enum status: {
    pending: "pending",
    in_progress: "in_progress",
    completed: "completed"
  }

  # =====================
  # Validations
  # =====================

  # 必須
  validates :task_id, presence: true
  validates :membership_id, presence: true
  validates :status, presence: true

  # 同じタスクを同じ人に二重で割り当てない
  validates :task_id, uniqueness: { scope: :membership_id }

  # 日付の整合性
  validate :completed_date_after_due_date
  validate :completed_date_requires_completed_status

  private

  # completed_date は due_date より前にならない
  def completed_date_after_due_date
    return if completed_date.blank? || due_date.blank?

    if completed_date < due_date
      errors.add(:completed_date, "は期限日以降である必要があります")
    end
  end

  # completed_date があるなら status は completed
  def completed_date_requires_completed_status
    return if completed_date.blank?

    unless status == "completed"
      errors.add(:status, "が completed のときのみ completed_date を設定できます")
    end
  end
end