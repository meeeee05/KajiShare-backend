# spec/factories/recurring_tasks.rb
# RSpec専用テストデータ生成
FactoryBot.define do
  factory :recurring_task do
    association :group
    association :creator, factory: :user

    sequence(:name) { |n| "Recurring Task #{n}" }
    description { "定期タスクの説明" }
    point { 3 }
    schedule_type { "weekly" }
    day_of_week { 1 }
    starts_on { Date.current }
    active { true }
  end
end