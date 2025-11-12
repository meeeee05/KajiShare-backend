class Task < ApplicationRecord
  
  #model関連付け
  belongs_to :group
  has_many :assignments, dependent: :destroy
end
