# spec/factories/users.rb
# RSpec専用テストデータ生成
FactoryBot.define do
  factory :user do
    sequence(:google_sub) { |n| "google_sub_#{n}" }
    sequence(:name) { |n| "Test User #{n}" }
    sequence(:email) { |n| "test#{n}@example.com" }
    picture { "https://example.com/avatar.png" }
    account_type { "user" }

    trait :admin do
      account_type { "admin" }
    end
  end
end
