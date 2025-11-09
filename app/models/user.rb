class User < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships
  has_many :assignments, dependent: :destroy
  has_many :evaluations, dependent: :destroy

  #バリデーション
  validates :google_sub, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
end
