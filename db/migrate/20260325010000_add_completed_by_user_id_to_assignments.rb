class AddCompletedByUserIdToAssignments < ActiveRecord::Migration[8.0]
  def up
    add_column :assignments, :completed_by_user_id, :bigint
    add_index :assignments, :completed_by_user_id
    add_foreign_key :assignments, :users, column: :completed_by_user_id

    execute <<~SQL
      UPDATE assignments
      SET completed_by_user_id = memberships.user_id
      FROM memberships
      WHERE assignments.membership_id = memberships.id
        AND assignments.completed_date IS NOT NULL
        AND assignments.completed_by_user_id IS NULL;
    SQL
  end

  def down
    remove_foreign_key :assignments, column: :completed_by_user_id
    remove_index :assignments, :completed_by_user_id
    remove_column :assignments, :completed_by_user_id
  end
end
