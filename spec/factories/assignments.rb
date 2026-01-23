# spec/factories/assignments.rb
# RSpec専用テストデータ生成
FactoryBot.define do
  factory :assignment do
    association :task
    association :membership
    due_date { 1.week.from_now }
    status { "pending" }
    comment { "Test assignment comment" }

    trait :completed do
      status { "completed" }
      completed_date { 1.day.ago }
    end

    trait :in_progress do
      status { "in_progress" }
    end
  end
end
