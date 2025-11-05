#バリデーション
class User < ApplicationRecord
  validates :google_sub, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
end
