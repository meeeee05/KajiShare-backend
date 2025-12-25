class AddUniqueIndexToEvaluations < ActiveRecord::Migration[8.0]
  def change
    # 既存の assignment_id インデックスを削除（新しい複合インデックスに含まれるため）
    remove_index :evaluations, :assignment_id if index_exists?(:evaluations, :assignment_id)
    
    # assignment_id と evaluator_id の複合ユニークインデックスを追加
    # 同じ評価者が同じAssignmentを2回評価することを防ぐ
    add_index :evaluations, [:assignment_id, :evaluator_id], unique: true, name: 'index_evaluations_on_assignment_and_evaluator'
  end
end
