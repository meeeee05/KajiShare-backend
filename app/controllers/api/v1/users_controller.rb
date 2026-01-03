module Api
  module V1
    class UsersController < ApplicationController
      before_action :set_user, only: [:show, :update, :destroy]
      before_action :authenticate_user!  # 全アクションで認証必須
      before_action :check_user_permission, only: [:show, :update, :destroy]  # 自分の情報のみアクセス可能

      # GET /api/v1/users - 現在のユーザーの情報のみ返す（セキュリティ向上）
      def index
        render json: [current_user], each_serializer: UserSerializer
      end

      def show
        render_user_success(@user)
      end

      def create
        user = User.new(user_params)
        
        if user.save
          render_user_success(user, :created)
        else
          handle_unprocessable_entity(user.errors.full_messages)
        end
      end

      def update
        if @user.update(user_params)
          render_user_success(@user)
        else
          handle_unprocessable_entity(@user.errors.full_messages)
        end
      end

      def destroy
        @user.destroy
        head :no_content
      end

      private

      def set_user
        @user = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("User with ID #{params[:id]} not found")
      end

      def user_params
        params.require(:user).permit(:google_sub, :name, :email, :picture, :account_type)
      end

      # ユーザー情報のJSONレスポンスを生成
      def render_user_success(user, status = :ok)
        render json: user, serializer: UserSerializer, status: status
      end

      # ユーザー権限チェック：自分の情報のみアクセス可能
      def check_user_permission
        return handle_forbidden("You can only access your own user information") unless @user.id == current_user.id
      end
    end
  end
end