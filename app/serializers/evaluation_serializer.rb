class EvaluationSerializer < ActiveModel::Serializer
  attributes :id, :score, :comment

  # 関連データ
  belongs_to :assignment, serializer: AssignmentSerializer

  # カスタム属性
  attribute :assignment_task_name
  attribute :evaluated_user_name
  attribute :evaluator_name
  attribute :score_label

  def assignment_task_name
    object.assignment&.task&.name
  end

  def evaluated_user_name
    object.assignment&.membership&.user&.name
  end

  def evaluator_name
    # 評価者の情報を取得（コンテキストから）
    instance_options[:current_user]&.name
  end

  def score_label
    case object.score
    when 5
      'Excellent'
    when 4
      'Good'
    when 3
      'Average'
    when 2
      'Below Average'
    when 1
      'Poor'
    else
      'Unrated'
    end
  end
end
