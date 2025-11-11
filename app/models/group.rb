class Group < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :expenses, dependent: :destroy
  has_many :tasks, dependent: :destroy
end
