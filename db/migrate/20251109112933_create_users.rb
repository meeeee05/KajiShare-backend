class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :google_sub
      t.string :name
      t.string :email
      t.string :picture
      t.string :account_type

      t.timestamps
    end
  end
end
