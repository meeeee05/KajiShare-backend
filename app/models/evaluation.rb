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

  # コメント（任意・最大100文字）
  validates :feedback,
            length: { maximum: 100 },
            allow_blank: true

  # 完了したタスクのみ評価可能
  # assignmentテーブルのstatusカラムが"completed"の時のみ評価を許可
  validate :assignment_must_be_completed

  private

  # Assignmentのstatusが"completed"でない場合は評価を作成できない
  def assignment_must_be_completed
    # assignmentがblankの時は何もしない
    return if assignment.blank?

    unless assignment.completed?
      errors.add(:assignment, "は完了状態でないと評価できません")
    end
  end
end
