class Assignment < ApplicationRecord

  #model関連付け
  belongs_to :task
  belongs_to :membership
  has_many :evaluations, dependent: :destroy

  #status
  #enum status: { pending: "pending", in_progress: "in_progress", completed: "completed" }

end