class CreateRecurringTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_tasks do |t|
      t.references :group, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :point, null: false
      t.string :schedule_type, null: false
      t.integer :day_of_week
      t.integer :interval_days
      t.date :starts_on, null: false
      t.boolean :active, null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :recurring_tasks, :active
    add_index :recurring_tasks, :schedule_type
  end
end
