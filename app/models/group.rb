class Group < ApplicationRecord
  #model関連付け 
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :tasks, dependent: :destroy
  has_many :assignments, through: :tasks, dependent: :destroy
  has_many :evaluations, through: :assignments, dependent: :destroy

  # バリデーション
  validates :name,
            presence: true,
            length: { maximum: 100 }

  validates :share_key,
            presence: true,
            uniqueness: true

  validates :assign_mode,
            presence: true,
            inclusion: { in: %w[equal ratio manual] }

  validates :balance_type,
            presence: true,
            inclusion: { in: %w[point time] }

  validates :active,
            inclusion: { in: [true, false] }
end