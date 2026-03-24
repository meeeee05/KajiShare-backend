class AddUniqueIndexToTasksGroupIdAndName < ActiveRecord::Migration[8.0]
  def change
    add_index :tasks, [:group_id, :name], unique: true
  end
end
