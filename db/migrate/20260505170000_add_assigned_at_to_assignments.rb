class AddAssignedAtToAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :assignments, :assigned_at, :datetime
    add_index :assignments, :assigned_at
  end
end
