class SimpleGroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :share_key, :assign_mode, :balance_type, :active, :members_count

  # メンバー数をカウント
  def members_count
    object.memberships.where(active: true).count
  end
end
