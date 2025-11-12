class AddMembershipIdToAssignments < ActiveRecord::Migration[8.0]
  def change
    add_reference :assignments, :membership, null: false, foreign_key: true
  end
end
