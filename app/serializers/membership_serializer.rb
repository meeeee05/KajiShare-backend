class MembershipSerializer < ActiveModel::Serializer
  attributes :id, :role, :workload_ratio, :active, :user_name, :group_name, 
             :assignments_count, :completed_assignments_count

  belongs_to :user, serializer: BasicUserSerializer
  belongs_to :group, serializer: BasicGroupSerializer

  # ユーザー名取得
  def user_name
    user&.name
  end

  # グループ名取得
  def group_name
    group&.name
  end

  # メンバーに割り当てられた課題の総数をカウント
  def assignments_count
    user_assignments.count
  end
 
  # メンバーが完了した課題の数をカウント
  def completed_assignments_count
    user_assignments.completed.count
  end

  private

  # ユーザーに割り当てられた課題を取得
  def user_assignments
    @user_assignments ||= object.assignments
  end

  def user
    @user ||= object.user
  end

  def group
    @group ||= object.group
  end
end
