class Group < ApplicationRecord
  #model関連付け 
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :tasks, dependent: :destroy
  has_many :assignments, through: :tasks, dependent: :destroy
  has_many :evaluations, through: :assignments, dependent: :destroy

  validates :name, presence: true
end
