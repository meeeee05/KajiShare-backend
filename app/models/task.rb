class Task < ApplicationRecord
  # model関連付け
  belongs_to :group
  belongs_to :source_recurring_task, class_name: "RecurringTask", optional: true
  has_many :assignments, dependent: :destroy

  # Assignmentのstatusを管理
  scope :completed, lambda {
    left_joins(:assignments)
      .group(:id)
      .having('COUNT(assignments.id) > 0')
      .having(
        'COUNT(assignments.id) = SUM(CASE WHEN assignments.status = ? THEN 1 ELSE 0 END)',
        Assignment.statuses['completed']
      )
  }

  # Assignmentのstatusを管理 - 完了していないタスクのみを取得
  scope :incomplete, lambda {
    where.not(id: completed.select(:id))
  }

  validates :name, presence: true, length: { maximum: 50 }
  validate :manual_task_name_must_be_unique_within_group, if: :manual_task?
  validates :description, length: { maximum: 50 }, allow_blank: true
  validates :point,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5
            }

  private

  # 手動で生成したtaskか自動で生成されたtaskか判別
  def manual_task?
    scheduled_for.nil?
  end

  def manual_task_name_must_be_unique_within_group
    return if name.blank? || group_id.blank?

    duplicate_exists = self.class
                           .where(group_id: group_id, name: name, scheduled_for: nil)
                           .where.not(id: id)
                           .exists?
    return unless duplicate_exists

    errors.add(:base, "同じグループに同名タスクが既にあります")
  end
end
