class Task < ApplicationRecord
  belongs_to :group

  #model関連付け
  has_many :assignments, dependent: :destroy
end
