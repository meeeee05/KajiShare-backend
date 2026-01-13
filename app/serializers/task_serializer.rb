class TaskSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :point
  attributes :total_assignments, :completed_assignments, :pending_assignments, :completion_rate

  # 関連データ
  belongs_to :group, serializer: BasicGroupSerializer
  has_many :assignments, serializer: AssignmentSerializer

  # アサインメント統計情報をメモ化して効率化
  def assignment_stats
    @assignment_stats ||= begin
      assignments = object.assignments
      completed = assignments.where.not(completed_date: nil)
      {
        total: assignments.count,
        completed: completed.count,
        pending: assignments.count - completed.count
      }
    end
  end

  # 総アサインメント数を取得
  def total_assignments
    assignment_stats[:total]
  end

  # 完了済みアサインメントの数を取得
  def completed_assignments
    assignment_stats[:completed]
  end

  # 未完了（保留中）のアサインメント数を取得
  def pending_assignments
    assignment_stats[:pending]
  end

  # タスクの完了率を取得
  def completion_rate
    return 0 if assignment_stats[:total] == 0
    (assignment_stats[:completed].to_f / assignment_stats[:total] * 100).round(2)
  end
end
