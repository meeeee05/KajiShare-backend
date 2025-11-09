class CreateEvaluations < ActiveRecord::Migration[8.0]
  def change
    create_table :evaluations do |t|
      t.references :assignment, null: false, foreign_key: true
      t.integer :evaluator_id
      t.integer :score
      t.text :feedback

      t.timestamps
    end
  end
end
