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

  # グループ内workload_ratio合計が100を超えないようにする
  validate :workload_ratio_sum_within_group

  # グループ内workload_ratio合計が100でないとNG
  validate :workload_ratio_sum_must_be_100, on: :create

  private

  # 小数第一位まで許可
  def workload_ratio_precision
    return if workload_ratio.blank?
    if (workload_ratio * 10) != (workload_ratio * 10).round
      errors.add(:workload_ratio, "は小数第一位までの値を入力してください")
    end
  end

  def workload_ratio_sum_within_group
    return if workload_ratio.blank? || group_id.blank?
    # 既存メンバーの合計（自分が未保存なら含まれない）
    sum = group.memberships.where.not(id: id).sum(:workload_ratio) || 0
    if sum + workload_ratio > 100
      errors.add(:workload_ratio, 'グループ内のworkload_ratio合計が100を超えています')
    end
  end

  def workload_ratio_sum_must_be_100
    return if workload_ratio.blank? || group_id.blank?
    # 新規作成時のみチェック
    sum = group.memberships.sum(:workload_ratio).to_f + workload_ratio.to_f
    if sum != 100.0
      errors.add(:workload_ratio, 'グループ内のworkload_ratio合計が100である必要があります')
    end
  end

end