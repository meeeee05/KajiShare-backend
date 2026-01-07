class MembershipSerializer < ActiveModel::Serializer
  attributes :id, :role, :workload_ratio, :active, :user_name, :group_name, 
             :assignments_count, :completed_assignments_count

  belongs_to :user, serializer: SimpleUserSerializer
  belongs_to :group, serializer: SimpleGroupSerializer

  def user_name
    user&.name
  end

  def group_name
    group&.name
  end

  def assignments_count
    user_assignments.count
  end

  def completed_assignments_count
    user_assignments.completed.count
  end

  private

  def user_assignments
    @user_assignments ||= object.assignments
  end

  def user
    @user ||= object.user
  end

  def group
    @group ||= object.group
  end
end
