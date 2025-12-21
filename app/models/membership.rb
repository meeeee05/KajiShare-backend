class Membership < ApplicationRecord
  #model関連付け
  belongs_to :user
  belongs_to :group
  has_many :assignments, dependent: :destroy
  has_many :evaluations, through: :assignments, dependent: :destroy

  #バリデーション（フォーマットチェック）
  validates :role, presence: true, inclusion: { in: %w[admin member] }

  validates :user_id, uniqueness: {
    scope: :group_id,
    message: "はすでにこのグループに参加しています"
  }

  validates :workload_ratio,
            numericality: {
              
              # 0より大きく100以下の値を許可（小数可）
              greater_than: 0,
              less_than_or_equal_to: 100
            },
            allow_nil: true
end