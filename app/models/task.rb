class Task < ApplicationRecord
  # model関連付け
  belongs_to :group
  has_many :assignments, dependent: :destroy

  # バリデーション
  validates :name, presence: true, length: { maximum: 50 }
  validates :description, length: { maximum: 50 }, allow_blank: true
  validates :point,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5
            }
end
