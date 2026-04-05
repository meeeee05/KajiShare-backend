class ChangeUniqueIndexOnAssignmentsToTaskAndMembership < ActiveRecord::Migration[8.0]
  def up
    remove_index :assignments, :task_id if index_exists?(:assignments, :task_id)
    add_index :assignments, [:task_id, :membership_id], unique: true, name: "index_assignments_on_task_id_and_membership_id"
  end

  def down
    remove_index :assignments, name: "index_assignments_on_task_id_and_membership_id" if index_exists?(:assignments, [:task_id, :membership_id], name: "index_assignments_on_task_id_and_membership_id")
    add_index :assignments, :task_id, unique: true
  end
end
