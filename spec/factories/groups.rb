# spec/factories/groups.rb
FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "Test Group #{n}" }
    sequence(:share_key) { |n| "share_key_#{n}" }
    assign_mode { "manual" }
    balance_type { "point" }
    active { true }
  end
end
