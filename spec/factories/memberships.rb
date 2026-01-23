# spec/factories/memberships.rb
# RSpec専用テストデータ生成
FactoryBot.define do
  factory :membership do
    association :user
    association :group
    role { "member" }
    workload_ratio { 1.0 }
    active { true }

    trait :admin do
      role { "admin" }
    end

    trait :inactive do
      active { false }
    end
  end
end
