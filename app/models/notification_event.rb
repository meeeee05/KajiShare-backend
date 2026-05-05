class NotificationEvent < ApplicationRecord
  belongs_to :recipient_user, class_name: "User", foreign_key: :recipient_user_id
  belongs_to :actor_user, class_name: "User", foreign_key: :actor_user_id, optional: true
  belongs_to :group, optional: true
  belongs_to :task, optional: true
  belongs_to :assignment, optional: true

  validates :event_type, :recipient_user_id, :occurred_at, presence: true

  scope :task_assigned, -> { where(event_type: "task_assigned") }
end
