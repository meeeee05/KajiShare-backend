class AddRecurringColumnsToTasks < ActiveRecord::Migration[8.0]
  def up
    add_reference :tasks, :source_recurring_task, foreign_key: { to_table: :recurring_tasks }
    add_column :tasks, :scheduled_for, :date
    add_column :tasks, :auto_generated, :boolean, null: false, default: false

    remove_index :tasks, name: "index_tasks_on_group_id_and_name" if index_exists?(:tasks, [:group_id, :name], name: "index_tasks_on_group_id_and_name")

    add_index :tasks, [:group_id, :name], unique: true, where: "scheduled_for IS NULL", name: "index_tasks_on_group_id_and_name_manual"
    add_index :tasks, [:group_id, :source_recurring_task_id, :scheduled_for], unique: true, name: "index_tasks_on_group_recurring_source_and_scheduled_for"
  end

  def down
    remove_index :tasks, name: "index_tasks_on_group_recurring_source_and_scheduled_for" if index_exists?(:tasks, [:group_id, :source_recurring_task_id, :scheduled_for], name: "index_tasks_on_group_recurring_source_and_scheduled_for")
    remove_index :tasks, name: "index_tasks_on_group_id_and_name_manual" if index_exists?(:tasks, [:group_id, :name], name: "index_tasks_on_group_id_and_name_manual")

    add_index :tasks, [:group_id, :name], unique: true, name: "index_tasks_on_group_id_and_name"

    remove_column :tasks, :auto_generated if column_exists?(:tasks, :auto_generated)
    remove_column :tasks, :scheduled_for if column_exists?(:tasks, :scheduled_for)
    remove_reference :tasks, :source_recurring_task if column_exists?(:tasks, :source_recurring_task_id)
  end
end
