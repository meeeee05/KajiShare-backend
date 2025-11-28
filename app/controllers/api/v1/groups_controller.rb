class Api::V1::GroupsController < ApplicationController
  before_action :set_group, only: [:show, :update, :destroy]
  # ログインしているかどうか
  before_action :authenticate_user!, only: [:create, :update, :destroy]
  before_action :check_admin_permission, only: [:update, :destroy]

  # GET /api/v1/groups
  def index
    groups = Group.all
    render json: groups
  end

  # GET /api/v1/groups/:id
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

  # 権限チェック：Adminのみがメンバー（グループ？）の更新・削除を実行可能
  # Admin権限を持つユーザーのみに操作を許可
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