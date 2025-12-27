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

  # 同じタスクを同じ人に二重で割り当てない
  validates :task_id, uniqueness: { scope: :membership_id }

  # completed のときは completed_date 必須
  validates :completed_date, presence: true, if: :completed?

  # コールバック
  before_validation :sync_status_with_completed_date

  private

  # completed_date は due_date より前にならない
  def completed_date_after_due_date
    return if completed_date.blank? || due_date.blank?

    if completed_date < due_date
      errors.add(:completed_date, "は期限日以降である必要があります")
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