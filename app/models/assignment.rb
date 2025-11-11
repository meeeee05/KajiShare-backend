class Assignment < ApplicationRecord
  belongs_to :task
  belongs_to :user

  #status管理
  enum status: { pending: 'pending', done: 'done', skipped: 'skipped' }
end
