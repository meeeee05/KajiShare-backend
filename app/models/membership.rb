class Membership < ApplicationRecord
  #model関連付け
  belongs_to :user
  belongs_to :group
  has_many :assignments, dependent: :destroy
  has_many :evaluations, through: :assignments, dependent: :destroy

  # ロール管理
  enum :role, { member: "member", admin: "admin" }

  #　バリデーション
  validates :role, presence: true

  validates :user_id, uniqueness:
  {
    scope: :group_id,
    message: "はすでにこのグループに参加しています"
  }

  validates :workload_ratio,
            numericality: {
              greater_than: 0,
              less_than_or_equal_to: 100
            },
            allow_nil: true
  
  # 小数第一位までの精度チェック
  validate :workload_ratio_precision

  private

  # 小数第一位まで許可
  def workload_ratio_precision
    return if workload_ratio.blank?
    if (workload_ratio * 10) != (workload_ratio * 10).round
      errors.add(:workload_ratio, "は小数第一位までの値を入力してください")
    end
  end

end