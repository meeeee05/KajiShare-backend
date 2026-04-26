class RecurringTask < ApplicationRecord
  SCHEDULE_TYPES = %w[weekly every_n_days].freeze

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
            if: :weekly?
  validates :interval_days,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 },
            presence: true,
            if: :every_n_days?

  validate :exclusive_schedule_fields

  # taskの周期設定を判別
  def weekly?
    schedule_type == "weekly"
  end

  def every_n_days?
    schedule_type == "every_n_days"
  end

  private

  # 週次設定とN日おき設定を混在させない
  def exclusive_schedule_fields
    if weekly? && interval_days.present?
      errors.add(:interval_days, "週次設定では指定できません")
    end

    if every_n_days? && day_of_week.present?
      errors.add(:day_of_week, "N日おき設定では指定できません")
    end
  end
end
