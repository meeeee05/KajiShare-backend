class Evaluation < ApplicationRecord
  #model関連付け
  belongs_to :assignment
  belongs_to :evaluator, class_name: 'User', foreign_key: 'evaluator_id'

  #コメントを持つ場合のバリデーション
  validates :score, length: { maximum: 500 }, allow_blank: true
  #validates :feedback, length: { maximum: 500 }, allow_blank: true

  #評価スコア（例: 1〜5）
  validates :score, inclusion: { in: 1..5 }
end
