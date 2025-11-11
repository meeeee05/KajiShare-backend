class Assignment < ApplicationRecord
  #model関連付け
  belongs_to :task
  belongs_to :user
  has_many :evaluations, dependent: :destroy

  validates :status, presence: true

  #status管理
  enum status: { pending: 'pending', done: 'done', skipped: 'skipped' }
end
