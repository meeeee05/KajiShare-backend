class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.references :group, null: false, foreign_key: true
      t.string :name
      t.integer :point
      t.text :description

      t.timestamps
    end
  end
end
