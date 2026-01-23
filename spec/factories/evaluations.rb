# spec/factories/evaluations.rb
# RSpec専用テストデータ生成
FactoryBot.define do
  factory :evaluation do
    association :assignment, :completed, due_date: Date.yesterday
    evaluator_id { create(:user).id }
    score { 5 }
    feedback { "Great job!" }
  end
end
