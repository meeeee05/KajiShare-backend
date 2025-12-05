class SimpleUserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :picture, :account_type
  
  # has_many がない = 他のSerializerを呼ばない
  # attribute で関連データを取得しない
end
