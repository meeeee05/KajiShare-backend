class User < ApplicationRecord
  #バリデーション
  validates :google_sub, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  #model関連付け
  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships
  has_many :assignments, through: :memberships, dependent: :destroy
  has_many :evaluations, foreign_key: :evaluator_id, dependent: :destroy


  validates :google_sub, :name, :email, presence: true
end
