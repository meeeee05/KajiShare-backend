class AddCreatedByToGroups < ActiveRecord::Migration[8.0]
  def change
    add_reference :groups, :created_by, foreign_key: { to_table: :users }, index: true
  end
end
