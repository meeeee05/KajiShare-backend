class RecurringTaskSerializer < ActiveModel::Serializer
  attributes :id,
             :group_id,
             :created_by_id,
             :name,
             :description,
             :point,
             :schedule_type,
             :day_of_week,
             :starts_on,
             :active,
             :created_at,
             :updated_at
end
