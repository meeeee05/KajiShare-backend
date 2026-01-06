class EvaluationSerializer < ActiveModel::Serializer
  attributes :id, :score, :feedback, :assignment_task_name, :evaluated_user_name, :evaluator_name, :score_label

  # 関連データ
  belongs_to :assignment, serializer: AssignmentSerializer

  def assignment_task_name
    object.assignment&.task&.name
  end

  def evaluated_user_name
    object.assignment&.membership&.user&.name
  end

  def evaluator_name
    instance_options[:current_user]&.name
  end

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
