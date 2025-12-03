class GroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :share_key, :assign_mode, :balance_type, :active, :created_at, :updated_at

  # 関連データの包含
  has_many :memberships, serializer: MembershipSerializer
  has_many :tasks, serializer: TaskSerializer

  # カスタム属性
  attribute :members_count
  attribute :admin_users
  attribute :member_users

  def members_count
    object.memberships.where(active: true).count
  end

  def admin_users
    object.memberships.includes(:user).where(role: 'admin', active: true).map(&:user)
  end

  def member_users  
    object.memberships.includes(:user).where(role: 'member', active: true).map(&:user)
  end
end
