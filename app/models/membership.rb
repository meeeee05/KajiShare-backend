class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  enum role: { member: 0, owner: 1 }

  validates :role, presence: true
end
