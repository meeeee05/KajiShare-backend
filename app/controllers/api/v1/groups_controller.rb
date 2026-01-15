class Api::V1::GroupsController < ApplicationController
  before_action :set_group, only: [:show, :update, :destroy]
  # ログインしているかどうか
  before_action :authenticate_user!  # 全アクションで認証必須
  before_action :check_member_permission, only: [:index, :show]  # 参照はメンバー権限以上
  before_action :check_admin_permission, only: [:update, :destroy]

  # GET /api/v1/groups - 現在のユーザーが参加しているグループのみ返す
  def index
    # 現在のユーザーが参加している（アクティブな）グループのみ取得
    user_group_ids = current_user.memberships.where(active: true).pluck(:group_id)
    groups = Group.includes(:memberships, :tasks).where(id: user_group_ids)
    render json: groups, each_serializer: GroupSerializer
  end

  # GET /api/v1/groups/:id - グループメンバーのみアクセス可能
  def show
    render_group_success(@group)
  end

  # POST /api/v1/groups - グループ作成
  def create
    group = Group.new(group_params)

    ActiveRecord::Base.transaction do
      if group.save
        # グループ作成者を自動的にAdminとして追加
        membership = group.memberships.create!(
          user: current_user,
          role: "admin",
          active: true
        )
        Rails.logger.info "Group created: '#{group.name}' (ID: #{group.id}) by user #{current_user.name}"
        render_group_success(group, :created)
      else
        handle_unprocessable_entity(group.errors.full_messages)
      end
    end
  rescue => e
    Rails.logger.error "Group creation failed: #{e.message}"
    handle_unprocessable_entity(["Failed to create group: #{e.message}"])
  end

  # PATCH/PUT /api/v1/groups/:id - グループ情報編集（Admin権限が必要）
  def update
    if @group.update(group_params)
      Rails.logger.info "Group updated: '#{@group.name}' (ID: #{@group.id}) by admin #{current_user.name}"
      render_group_success(@group)
    else
      handle_unprocessable_entity(@group.errors.full_messages)
    end
  end

  # DELETE /api/v1/groups/:id - グループ情報削除（Admin権限が必要）
  def destroy
    begin
      # トランザクション内で削除
      ActiveRecord::Base.transaction do
        # 関連データの削除ログ作成
        Rails.logger.info "Deleting group '#{@group.name}' (ID: #{@group.id}) by admin user #{current_user.name}"
        
        # グループを削除（dependent: :destroyにより関連データも自動削除）
        @group.destroy!
        
        render json: { 
          message: "Group '#{@group.name}' has been successfully deleted",
          deleted_at: Time.current 
        }, status: :ok
      end
    rescue => e
      Rails.logger.error "Failed to delete group: #{e.message}"
      handle_unprocessable_entity(["Failed to delete group: #{e.message}"])
    end
  end

  private

  # group存在チェック
  def set_group
    @group = Group.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    handle_not_found("Group with ID #{params[:id]} not found")
  end

  # Strong Parameters：グループパラメータ許可設定(不正な属性の混入を防ぐ)
  def group_params
    params.require(:group).permit(:name, :share_key, :assign_mode, :balance_type, :active)
  end

  # 共通メソッド：指定されたグループに対するユーザーのメンバーシップを取得
  def current_user_membership(group_id)
    Membership.find_by(user_id: current_user.id, group_id: group_id)
  end

  # 共通メソッド：グループ情報のJSONレスポンスを生成
  def render_group_success(group, status = :ok)
    render json: group, serializer: GroupSerializer, status: status
  end

  # 権限チェック：指定されたグループのmember以上のみ操作可能
  def check_member_permission
    # indexアクションの場合は特別処理不要
    return if action_name == 'index'
    
    membership = current_user_membership(@group.id)

    return handle_forbidden("You are not a member of this group") if membership.nil?
    return handle_forbidden("Your membership is not active") unless membership.active?
  end

  # 権限チェック：Adminのみがグループの更新・削除を実行可能
  def check_admin_permission
    membership = current_user_membership(@group.id)

    return handle_forbidden("You are not a member of this group") if membership.nil?
    return handle_forbidden("Your membership is not active") unless membership.active?
    return handle_forbidden("You are not allowed to perform this action. Admin permission required.") unless membership.admin?
  end
end