# spec/factories/tasks.rb
# RSpec専用テストデータ生成
FactoryBot.define do
  factory :task do
    association :group
    sequence(:name) { |n| "Test Task #{n}" }
    description { "Test task description" }
    point { 10 }
  end
end
