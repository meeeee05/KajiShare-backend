# spec/factories/notification_events.rb
# RSpec専用テストデータ生成
FactoryBot.define do
  factory :notification_event do
    event_type { 'task_assigned' }
    association :recipient_user, factory: :user
    actor_user { nil }
    group { nil }
    task { nil }
    assignment { nil }
    occurred_at { Time.current }
    payload { {} }
  end
end