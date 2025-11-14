class Api::V1::GroupsController < ApplicationController
  # GET /api/v1/groups
  def index
    groups = Group.all
    render json: groups
  end

  # GET /api/v1/groups/:id
  def show
    group = Group.find(params[:id])
    render json: group
  end

  # POST /api/v1/groups
  def create
    group = Group.new(group_params)

    if group.save
      render json: group, status: :created
    else
      render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/groups/:id
  def update
    group = Group.find(params[:id])

    if group.update(group_params)
      render json: group
    else
      render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/groups/:id
  def destroy
    group = Group.find(params[:id])
    group.destroy
    head :no_content
  end

  private

  def group_params
    params.require(:group).andpermit(:name, :share_key, :assign_mode, :balance_type, :active)
  end
end