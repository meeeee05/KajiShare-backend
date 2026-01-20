# spec/factories/tasks.rb
FactoryBot.define do
  factory :task do
    association :group
    sequence(:name) { |n| "Test Task #{n}" }
    description { "Test task description" }
    point { 10 }
  end
end
