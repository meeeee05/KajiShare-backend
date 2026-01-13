class GroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :share_key, :assign_mode, :balance_type, :active,
             :members_count, :admin_users, :member_users

  # 関連データの包含(関連するオブジェクトを自動でJSONに含める)
  has_many :memberships, serializer: MembershipSerializer
  has_many :tasks, serializer: TaskSerializer

  # グループのアクティブメンバー数をカウント
  def members_count
    active_memberships.count
  end

  # 管理者ユーザーのリストを取得
  def admin_users
    users_by_role('admin')
  end

  # 一般ユーザーのリストを取得
  def member_users
    users_by_role('member')
  end

  private

  # アクティブなメンバーシップのみ取得
  def active_memberships
    object.memberships.where(active: true)
  end
  
  # 指定された権限に基づいてユーザーを取得
  def users_by_role(role)
    active_memberships.includes(:user).where(role: role).map(&:user)
  end
end
