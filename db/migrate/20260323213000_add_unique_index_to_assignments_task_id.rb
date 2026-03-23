class AddUniqueIndexToAssignmentsTaskId < ActiveRecord::Migration[8.0]
  def up
    remove_index :assignments, :task_id if index_exists?(:assignments, :task_id)
    add_index :assignments, :task_id, unique: true
  end

  def down
    remove_index :assignments, :task_id if index_exists?(:assignments, :task_id)
    add_index :assignments, :task_id
  end
end
