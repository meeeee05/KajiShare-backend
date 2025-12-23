class AddStatusToAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :assignments, :status, :string, default: "pending"
  end
end
