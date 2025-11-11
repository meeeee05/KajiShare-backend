class Task < ApplicationRecord
  belongs_to :group
  belongs_to :assigned_to, class_name: "User", optional: true

  validates :title, presence: true
end
