class TaskSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :point
  attributes :total_assignments, :not_started_assignments, :in_progress_assignments, :completed_assignments, :pending_assignments, :completion_rate

  # 関連データ
  belongs_to :group, serializer: BasicGroupSerializer
  has_many :assignments, serializer: AssignmentSerializer

  # アサインメント統計情報をメモ化して効率化
  def assignment_stats
    @assignment_stats ||= begin
      assignments = object.assignments
      not_started = assignments.where(status: Assignment.statuses[:not_started])
      in_progress = assignments.where(status: Assignment.statuses[:in_progress])
      completed = assignments.where(status: Assignment.statuses[:completed])
      {
        total: assignments.count,
        not_started: not_started.count,
        in_progress: in_progress.count,
        completed: completed.count,
        pending: not_started.count + in_progress.count
      }
    end
  end

  # 総アサインメント数を取得
  def total_assignments
    assignment_stats[:total]
  end

  # 進行中のアサインメント数を取得
  def in_progress_assignments
    assignment_stats[:in_progress]
  end

  # 完了済みアサインメントの数を取得
  def completed_assignments
    assignment_stats[:completed]
  end

  # 着手前のアサインメント数を取得
  def not_started_assignments
    assignment_stats[:not_started]
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
