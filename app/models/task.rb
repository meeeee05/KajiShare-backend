class Task < ApplicationRecord
  # model関連付け
  belongs_to :group
  has_many :assignments, dependent: :destroy

  # タスクのstatusを完了/未完了で管理
  scope :completed, lambda {
    left_joins(:assignments)
      .group(:id)
      .having('COUNT(assignments.id) > 0')
      .having(
        'COUNT(assignments.id) = SUM(CASE WHEN assignments.status = ? THEN 1 ELSE 0 END)',
        Assignment.statuses['completed']
      )
  }

  scope :incomplete, lambda {
    where.not(id: completed.select(:id))
  }

  # バリデーション
  validates :name, presence: true, length: { maximum: 50 }
  validates :description, length: { maximum: 50 }, allow_blank: true
  validates :point,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5
            }
end
