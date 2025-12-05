class AssignmentSerializer < ActiveModel::Serializer
  attributes :id, :assigned_to_id, :assigned_by_id, :due_date, :completed_date, 
             :comment

  # 関連データ
  belongs_to :task, serializer: TaskSerializer
  belongs_to :membership, serializer: MembershipSerializer

  # カスタム属性
  attribute :task_name
  attribute :assigned_to_name
  attribute :assigned_by_name
  attribute :status
  attribute :days_until_due
  attribute :is_overdue

  def task_name
    object.task&.name
  end

  def assigned_to_name
    object.membership&.user&.name
  end

  def assigned_by_name
    # assigned_by_idからユーザー名を取得
    return nil unless object.assigned_by_id
    User.find_by(id: object.assigned_by_id)&.name
  end

  def status
    return 'completed' if object.completed_date.present?
    return 'overdue' if object.due_date && object.due_date < Date.current
    'pending'
  end

  def days_until_due
    return nil unless object.due_date
    return 0 if object.completed_date.present?
    (object.due_date - Date.current).to_i
  end

  def is_overdue
    return false if object.completed_date.present?
    return false unless object.due_date
    object.due_date < Date.current
  end
end
