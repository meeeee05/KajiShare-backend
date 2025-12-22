class Evaluation < ApplicationRecord
  # model関連付け
  belongs_to :assignment
  belongs_to :evaluator,
             class_name: 'User',
             foreign_key: 'evaluator_id'

  # バリデーション
  # 評価スコア（必須・1〜5）
  validates :score,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5
            }

  # コメント（任意・最大500文字）
  validates :feedback,
            length: { maximum: 500 },
            allow_blank: true
end
