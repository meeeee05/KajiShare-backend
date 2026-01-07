class EvaluationSerializer < ActiveModel::Serializer
  attributes :id, :score, :feedback, :assignment_task_name, :evaluated_user_name, :evaluator_name, :score_label

  # 関連データ
  belongs_to :assignment, serializer: AssignmentSerializer

  #　評価対象のタスク名を取得
  def assignment_task_name
    object.assignment&.task&.name
  end

  # 評価対象のユーザー名を取得
  def evaluated_user_name
    object.assignment&.membership&.user&.name
  end

  # 評価者のユーザー名を取得
  def evaluator_name
    instance_options[:current_user]&.name
  end

  # スコア
  def score_label
    score_labels = {
      5 => 'Excellent',
      4 => 'Good', 
      3 => 'Average',
      2 => 'Below Average',
      1 => 'Poor'
    }
    score_labels[object.score] || 'Unrated'
  end
end
