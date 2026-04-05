class Assignment < ApplicationRecord

  #model関連付け
  belongs_to :task
  belongs_to :membership
  belongs_to :completed_by_user, class_name: 'User', foreign_key: :completed_by_user_id, optional: true
  has_many :evaluations, dependent: :destroy


  # ステータスを管理
  enum :status, {
    not_started: "着手前",
    in_progress: "in_progress", 
    completed: "completed"
  }

  # バリデーション
  validates :task_id, :membership_id, :status, presence: true
  validate :prevent_duplicate_task_assignment, on: :create

  # completed のときは completed_date 必須
  validates :completed_date, presence: true, if: :completed?
  validates :completed_by_user_id, presence: true, if: :completed?
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
    if completed_date.present?
      self.status = "completed"
      self.completed_by_user_id ||= membership&.user_id
    elsif status.blank? || (status == "completed" && will_save_change_to_completed_date?)
      # completed_date を明示的に nil に戻したときは completed のままにならないよう補正
      self.status = "not_started"
      self.completed_by_user_id = nil
    elsif status != "completed"
      self.completed_by_user_id = nil
    end
  end

  # 同一ユーザーへの同一task_id重複割り当てを禁止
  def prevent_duplicate_task_assignment
    return if task_id.blank? || membership_id.blank?

    existing = self.class.where(task_id: task_id, membership_id: membership_id).where.not(id: id).exists?
    return unless existing

    errors.add(:base, "同じタスクを同じユーザーに重複して割り当てることはできません")
  end
end