# spec/factories/groups.rb
# RSpec専用テストデータ生成
FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "Test Group #{n}" }
    sequence(:share_key) { |n| "share_key_#{n}" }
    assign_mode { "manual" }
    balance_type { "point" }
    active { true }
  end
end
