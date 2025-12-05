class TaskSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :point

  # 関連データ
  belongs_to :group, serializer: GroupSerializer
  has_many :assignments, serializer: AssignmentSerializer

  # カスタム属性
  attribute :group_name
  attribute :total_assignments
  attribute :completed_assignments
  attribute :pending_assignments
  attribute :completion_rate

  def group_name
    object.group&.name
  end

  def total_assignments
    object.assignments.count
  end

  def completed_assignments
    object.assignments.where.not(completed_date: nil).count
  end

  def pending_assignments
    object.assignments.where(completed_date: nil).count
  end

  def completion_rate
    return 0 if total_assignments == 0
    (completed_assignments.to_f / total_assignments * 100).round(2)
  end
end
