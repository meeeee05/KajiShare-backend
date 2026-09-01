class ApplicationJob < ActiveJob::Base
  # Jobs share the application database, so enqueue only after the surrounding
  # database transaction has committed successfully.
  self.enqueue_after_transaction_commit = true
end
