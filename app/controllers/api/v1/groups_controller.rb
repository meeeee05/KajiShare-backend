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
    groups = Group.where(id: user_group_ids)
    render json: groups
  end

  # GET /api/v1/groups/:id - グループメンバーのみアクセス可能
  def show
    render json: @group
  end

  # POST /api/v1/groups
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
        render json: group, status: :created
      else
        render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
      end
    end
  rescue => e
    render json: { error: "Failed to create group: #{e.message}" }, status: :unprocessable_entity
  end

  # PATCH/PUT /api/v1/groups/:id - Admin権限が必要（グループ情報編集）
  def update
    if @group.update(group_params)
      render json: @group
    else
      render json: { errors: @group.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/groups/:id - Admin権限が必要
  def destroy
    begin
      # トランザクション内で安全に削除
      ActiveRecord::Base.transaction do
        # 関連データの削除ログ
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
      render json: { error: "Failed to delete group: #{e.message}" }, status: :unprocessable_entity
    end
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def group_params
    params.require(:group).permit(:name, :share_key, :assign_mode, :balance_type, :active)
  end

  # Member権限チェック：指定されたグループのmember以上のみ操作可能
  def check_member_permission
    # indexアクションの場合は特別処理不要（indexで既にフィルタリング済み）
    return if action_name == 'index'
    
    membership = Membership.find_by(user_id: current_user.id, group_id: @group.id)

    # メンバー存在チェック
    if membership.nil?
      render json: { error: "You are not a member of this group" }, status: :forbidden
      return
    end

    # アクティブメンバーチェック(一時的に停止中のメンバーは拒否)
    unless membership.active?
      render json: { error: "Your membership is not active" }, status: :forbidden
    end
  end

  # 権限チェック：Adminのみがグループの更新・削除を実行可能
  def check_admin_permission
    membership = Membership.find_by(user_id: current_user.id, group_id: @group.id)

    # メンバー存在チェック
    if membership.nil?
      render json: { error: "You are not a member of this group" }, status: :forbidden
      return
    end

    # admin権限チェック
    if membership.role != "admin"
      render json: { error: "You are not allowed to perform this action. Admin permission required." }, status: :forbidden
    end
  end
end