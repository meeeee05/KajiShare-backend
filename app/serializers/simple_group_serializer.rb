class SimpleGroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :share_key, :assign_mode, :balance_type, :active, :members_count

  
  def members_count
    object.memberships.where(active: true).count
  end

  # has_many がない = 他のSerializerを呼ばない
  # attribute で関連データを取得しない

end
