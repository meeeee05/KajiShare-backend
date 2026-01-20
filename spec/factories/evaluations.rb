# spec/factories/evaluations.rb
FactoryBot.define do
  factory :evaluation do
    association :assignment, :completed
    evaluator_id { create(:user).id }
    score { 5 }
    feedback { "Great job!" }
  end
end
