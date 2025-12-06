class SimpleTaskSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :point
  
  # カスタム属性
  attribute :group_name

  def group_name
    object.group&.name
  end
end
