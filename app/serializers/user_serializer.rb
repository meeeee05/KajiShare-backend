class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :picture, :account_type, :groups_count, :active_groups

  # メンバーシップ（グループ参加情報）を取得
  has_many :memberships, serializer: MembershipSerializer, if: :include_memberships?

  # アクティブなグループ情報をメモ化(クエリ実行)
  def active_groups_data
    @active_groups_data ||= object.memberships.includes(:group).where(active: true)
  end

  def groups_count
    active_groups_data.count
  end

  def active_groups
    return [] unless include_memberships?
    active_groups_data.map(&:group)
  end

  private
  # メンバーシップ情報を含めるかどうかの判定
  def include_memberships?
    instance_options[:include_memberships] || false
  end
end
