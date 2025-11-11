class Evaluation < ApplicationRecord
  belongs_to :assignment
  belongs_to :evaluator, class_name: 'User', foreign_key: 'evaluator_id'

  #コメントを持つ場合
  validates :comment, length: { maximum: 500 }, allow_blank: true

  #評価スコア（例: 1〜5）
  validates :score, inclusion: { in: 1..5 }
end
