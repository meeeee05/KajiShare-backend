class BasicTaskSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :point
  
  # カスタム属性
  attribute :group_name

  def group_name
    object.group&.name
  end

  # has_many がない = 他のSerializerを呼ばない
  # attribute で関連データを取得しない

end
