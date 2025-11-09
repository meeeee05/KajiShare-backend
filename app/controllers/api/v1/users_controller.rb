class Api::V1::UsersController < Api::V1::BaseController
  before_action :set_user, only: [:show, :update]

  def index
    users = User.all
    render_success({ users: users })
  end

  def show
    render_success({ user: @user })
  end

  def update
    if @user.update(user_params)
      render_success({ user: @user }, "User updated successfully")
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :picture)
  end
end
