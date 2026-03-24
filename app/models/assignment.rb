class Assignment < ApplicationRecord

  #model関連付け
  belongs_to :task
  belongs_to :membership
  has_many :evaluations, dependent: :destroy


  # ステータスを管理
  enum :status, {
    not_started: "着手前",
    in_progress: "in_progress", 
    completed: "completed"
  }

  # バリデーション
  validates :task_id, :membership_id, :status, presence: true
  validate :prevent_duplicate_task_assignment

  # completed のときは completed_date 必須
  validates :completed_date, presence: true, if: :completed?
  validate :completed_date_after_due_date

  # コールバック - ステータスと完了日の整合性を自動調整
  before_validation :sync_status_with_completed_date

  private

  # completed_date は due_date 以降であること
  def completed_date_after_due_date
    return unless completed_date.present? && due_date.present? && completed_date < due_date
    errors.add(:completed_date, "は期限日以降である必要があります")
  end

  # completed_date に基づいて status を completed に変更
  def sync_status_with_completed_date
    self.status = completed_date.present? ? "completed" : (status.blank? ? "not_started" : status)
  end

  # 同じtask_idの重複割り当てを禁止（同一ユーザー/他ユーザーでメッセージを出し分け）
  def prevent_duplicate_task_assignment
    return if task_id.blank? || membership_id.blank?

    existing = self.class.where(task_id: task_id).where.not(id: id).first
    return unless existing

    if existing.membership_id == membership_id
      errors.add(:base, "同じtask_idのタスクを同じユーザーに重複して割り当てることはできません")
    else
      errors.add(:base, "このタスクはすでに別のユーザーに割り当て済みです")
    end
  end
end