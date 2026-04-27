class RecurringTask < ApplicationRecord
  SCHEDULE_TYPES = %w[weekly biweekly].freeze

  # model関連付け
  belongs_to :group
  belongs_to :creator, class_name: "User", foreign_key: :created_by_id
  has_many :tasks, foreign_key: :source_recurring_task_id, dependent: :nullify

  validates :name, presence: true, length: { maximum: 50 }
  validates :point,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5
            }
  validates :schedule_type, inclusion: { in: SCHEDULE_TYPES }
  validates :starts_on, presence: true

  validates :day_of_week,
            inclusion: { in: 0..6 },
            presence: true,
            if: -> { schedule_type.in?(SCHEDULE_TYPES) }

  validate :interval_days_must_be_blank