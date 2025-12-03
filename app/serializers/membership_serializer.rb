class MembershipSerializer < ActiveModel::Serializer
  attributes :id, :role, :workload_ratio, :active, :created_at, :updated_at

  # 関連データ
  belongs_to :user, serializer: UserSerializer
  belongs_to :group, serializer: GroupSerializer

  # カスタム属性
  attribute :user_name
  attribute :group_name
  attribute :assignments_count
  attribute :completed_assignments_count

  def user_name
    object.user&.name
  end

  def group_name
    object.group&.name
  end

  def assignments_count
    object.assignments.count
  end

  def completed_assignments_count
    object.assignments.where.not(completed_date: nil).count
  end
end
