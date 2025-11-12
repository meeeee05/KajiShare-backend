class Membership < ApplicationRecord
  #model関連付け
  belongs_to :user
  belongs_to :group

  validates :role, presence: true
end
