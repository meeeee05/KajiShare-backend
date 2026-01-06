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
            numericality: 
            {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5
            }

  # コメント（任意・最大100文字）
  validates :feedback,
            length: { maximum: 100 },
            allow_blank: true

  # 二重評価防止（同じ評価者が同じAssignmentを複数回評価することを防ぐ）
  validates :assignment_id, uniqueness: 
  {
    scope: :evaluator_id, message: "は既に評価済みです"
  }

  # 完了したタスクのみ評価可能
  # assignmentテーブルのstatusカラムが"completed"の時のみ評価を許可
  validate :assignment_must_be_completed

  private

  # Assignmentのstatusが"completed"でない場合は評価を作成できない
  def assignment_must_be_completed
    return unless assignment&.present? && !assignment.completed?
    errors.add(:assignment, "は完了状態でないと評価できません")
  end
end
