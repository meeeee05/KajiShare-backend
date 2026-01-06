class AssignmentSerializer < ActiveModel::Serializer
  attributes :id, :assigned_to_id, :assigned_by_id, :due_date, :completed_date, :comment,
             :task_name, :assigned_to_name, :assigned_by_name, :status, :days_until_due, :is_overdue

  # 関連データ
  belongs_to :task, serializer: SimpleTaskSerializer
  belongs_to :membership, serializer: MembershipSerializer

  def task_name
    object.task&.name
  end

  def assigned_to_name
    object.membership&.user&.name
  end

  # assigned_by_idからユーザー名を取得
  def assigned_by_name
    return nil unless object.assigned_by_id
    User.find_by(id: object.assigned_by_id)&.name
  end

  # データベースのstatusカラムを使用
  def status
    object.status
  end

  def days_until_due
    return nil unless object.due_date
    return 0 if completed?
    (object.due_date - Date.current).to_i
  end

  def is_overdue
    return false if completed? || object.due_date.blank?
    object.due_date < Date.current
  end

  private

  def completed?
    object.completed_date.present?
  end
end
