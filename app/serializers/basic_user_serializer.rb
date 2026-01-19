class BasicUserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :picture, :account_type
end
