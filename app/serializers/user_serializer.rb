class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :picture, :account_type

  # 条件付きでメンバーシップ（グループ参加情報）を取得
  has_many :memberships, serializer: MembershipSerializer, if: :include_memberships?

  # カスタム属性
  # テーブル内に存在しないデータを取得しにいく
  attribute :groups_count
  attribute :active_groups

  # アクティブなメンバーの数
  def groups_count
    object.memberships.where(active: true).count
  end

  # アクティブなグループの一覧 
  def active_groups
    return [] unless include_memberships?
    groups = object.memberships.includes(:group).where(active: true).map(&:group)
    groups.map { |group| BasicGroupSerializer.new(group).as_json }
  end

  # メンバーシップの情報を含めるかどうか判定
  def include_memberships?
    # コンテキストで制御
    instance_options[:include_memberships] || false
  end
end
