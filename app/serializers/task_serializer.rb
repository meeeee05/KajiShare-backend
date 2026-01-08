class TaskSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :point

  # 関連データ
  belongs_to :group, serializer: BasicGroupSerializer
  has_many :assignments, serializer: AssignmentSerializer

  # カスタム属性
  attribute :group_name
  attribute :total_assignments
  attribute :completed_assignments
  attribute :pending_assignments
  attribute :completion_rate

  # タスクが属するグループの名前を取得
  def group_name
    object.group&.name
  end

  # タスクに関連するアサインメント（割り当て）の総数を取得
  def total_assignments
    object.assignments.count
  end

  # 完了済みアサインメントの数を取得
  def completed_assignments
    object.assignments.where.not(completed_date: nil).count
  end

  # 未完了（保留中）のアサインメント数を取得
  def pending_assignments
    object.assignments.where(completed_date: nil).count
  end

  # スクの完了率を取得
  def completion_rate
    return 0 if total_assignments == 0
    (completed_assignments.to_f / total_assignments * 100).round(2)
  end
end
