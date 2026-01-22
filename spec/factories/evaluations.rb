# spec/factories/evaluations.rb
FactoryBot.define do
  factory :evaluation do
    association :assignment, :completed, due_date: Date.yesterday
    evaluator_id { create(:user).id }
    score { 5 }
    feedback { "Great job!" }
  end
end
