module GroupMembershipValidation
  extend ActiveSupport::Concern

  private

  # 指定グループにおける現在ユーザーのメンバーシップを取得
  def current_user_membership(group_id)
    Membership.find_by(user_id: current_user.id, group_id: group_id)
  end

  # メンバーシップの存在/有効状態を共通検証
  def validate_membership(membership)
    return handle_forbidden("このグループのメンバーではありません") && nil if membership.nil?
    return handle_forbidden("メンバーシップが無効です") && nil unless membership.active?

    membership
  end
end
