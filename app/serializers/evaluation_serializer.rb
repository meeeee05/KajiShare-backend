class EvaluationSerializer < ActiveModel::Serializer
  attributes :id, :score, :feedback, :evaluator_id, :evaluated_user_id, :task_id, :assignment_status,
             :assignment_task_name, :evaluated_user_name, :evaluator_name

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

  # 評価対象ユーザーのIDを取得
  def evaluated_user_id
    object.assignment&.membership&.user_id
  end

  # 評価対象タスクのIDを取得
  def task_id
    object.assignment&.task_id
  end

  # 評価対象Assignmentのステータスを取得
  def assignment_status
    object.assignment&.status
  end

  # 評価者のユーザー名を取得
  def evaluator_name
    object.evaluator&.name
  end
end
