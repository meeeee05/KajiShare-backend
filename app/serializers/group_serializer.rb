class GroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :share_key, :assign_mode, :balance_type, :active,
             :members_count, :admin_users, :member_users

  # 関連データの包含
  has_many :memberships, serializer: MembershipSerializer
  has_many :tasks, serializer: TaskSerializer

  def members_count
    active_memberships.count
  end

  def admin_users
    users_by_role('admin')
  end

  def member_users
    users_by_role('member')
  end

  private

  def active_memberships
    object.memberships.where(active: true)
  end

  def users_by_role(role)
    active_memberships.includes(:user).where(role: role).map(&:user)
  end
end
