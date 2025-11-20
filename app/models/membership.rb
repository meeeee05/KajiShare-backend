class Membership < ApplicationRecord
  #model関連付け
  belongs_to :user
  belongs_to :group
  has_many :assignments, dependent: :destroy
  has_many :evaluations, through: :assignments, dependent: :destroy

  validates :role, presence: true
end
