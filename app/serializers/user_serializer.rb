class UserSerializer < ActiveModel::Serializer
  attributes :id, :google_sub, :name, :email, :picture, :account_type, :created_at, :updated_at

  # 関連データの包含（オプション）
  has_many :memberships, serializer: MembershipSerializer, if: :include_memberships?

  # カスタム属性
  attribute :groups_count
  attribute :active_groups

  def groups_count
    object.memberships.where(active: true).count
  end

  def active_groups
    return [] unless include_memberships?
    object.memberships.includes(:group).where(active: true).map(&:group)
  end

  private

  def include_memberships?
    # コンテキストで制御可能
    instance_options[:include_memberships] || false
  end
end
