class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :name
      t.string :share_key
      t.string :assign_mode
      t.string :balance_type
      t.boolean :active

      t.timestamps
    end
  end
end
