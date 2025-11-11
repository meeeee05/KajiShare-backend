class User < ApplicationRecord
  #バリデーション
  validates :google_sub, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships
  has_many :expenses, dependent: :destroy
  has_many :tasks, foreign_key: :assigned_to_id, dependent: :destroy
end
