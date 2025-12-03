class SimpleUserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :picture, :account_type
end
