class Api::V1::GroupsController < ApplicationController
  before_action :set_group, only: [:show, :update, :destroy]
  before_action :authenticate_user!, only: [:update, :destroy]
  before_action :check_admin_permission, only: [:update, :destroy]

  #GET /api/v1/groups
  def index
    groups = Group.all
    render json: groups
  end

  #GET /api/v1/groups/:id
  def show
    render json: @group
  end

  #POST /api/v1/groups
  def create
    group = Group.new(group_params)

    if group.save
      render json: group, status: :created
    else
      render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
    end
  end

  #PATCH/PUT /api/v1/groups/:id
  def update
    if @group.update(group_params)
      render json: @group
    else
      render json: { errors: @group.errors.full_messages }, status: :unprocessable_entity
    end
  end

  #DELETE /api/v1/groups/:id
  def destroy
    @group.destroy
    head :no_content
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def group_params
    params.require(:group).permit(:name, :share_key, :assign_mode, :balance_type, :active)
  end

  #権限チェック：Adminのみがグループの更新・削除を実行可能
  def check_admin_permission
    membership = Membership.find_by(user_id: current_user.id, group_id: @group.id)

    #メンバー存在チェック
    if membership.nil?
      render json: { error: "You are not a member of this group" }, status: :forbidden
      return
    end

    #admin権限チェック
    if membership.role != "admin"
      render json: { error: "You are not allowed to perform this action. Admin permission required." }, status: :forbidden
    end
  end
end