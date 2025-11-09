class CreateAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :assignments do |t|
      t.references :task, null: false, foreign_key: true
      t.integer :assigned_to_id
      t.integer :assigned_by_id
      t.date :due_date
      t.date :completed_date
      t.text :comment

      t.timestamps
    end
  end
end
