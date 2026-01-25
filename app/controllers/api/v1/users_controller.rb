module Api
  module V1
    class UsersController < ApplicationController
      before_action :set_user, only: [:show, :update, :destroy]
      before_action :authenticate_user!, except: [:create]  # createは認証不要（新規登録）
      before_action :check_user_permission, only: [:show, :update, :destroy]  # 自分の情報のみアクセス可能

      # GET /api/v1/users - 現在のユーザーの情報のみ返す（セキュリティ向上）
      def index
        render json: current_user, serializer: UserSerializer
      end

      # GET /api/v1/users/:id
      def show
        render_user_success(@user)
      end

      # POST /api/v1/users
      def create
        # 既存ユーザーとの重複チェック
        return if check_user_duplicates

        user = User.new(user_params)

        if user.save
          Rails.logger.info "User created: '#{user.name}' (ID: #{user.id}, Email: #{user.email})"
          render_user_success(user, :created)
        else
          handle_unprocessable_entity(user.errors.full_messages)
        end
      rescue ActionController::ParameterMissing => e
        # ApplicationControllerでrescue_fromしているのでここで何もしない（400で返る）
        raise
      rescue StandardError => e
        handle_internal_error("Failed to create user: #{e.message}")
      end

      # PATCH/PUT /api/v1/users/:id
      def update
        begin
          if @user.update(user_params)
            Rails.logger.info "User updated: '#{@user.name}' (ID: #{@user.id}, Email: #{@user.email}) by user #{current_user.name}"
            render_user_success(@user)
          else
            handle_unprocessable_entity(@user.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to update user: #{e.message}")
        end
      end

      # DELETE /api/v1/users/:id
      def destroy
        begin
          # トランザクション内で削除
          ActiveRecord::Base.transaction do
            # 削除ログ記録
            Rails.logger.info "Deleting user '#{@user.name}' (ID: #{@user.id}, Email: #{@user.email}) by user #{current_user.name}"
            
            # 関連データの影響を記録（軽量版）
            Rails.logger.info "Deleting user with all associated memberships and assignments"
            
            # ユーザーを削除（destroyにより関連データも自動削除）
            @user.destroy!
            
            render json: { 
              message: "User '#{@user.name}' has been successfully deleted",
              deleted_at: Time.current
            }, status: :ok
          end
        rescue StandardError => e
          Rails.logger.error "Failed to delete user: #{e.message}"
          handle_internal_error("Failed to delete user: #{e.message}")
        end
      end

      private

      # IDに基づきユーザーを取得
      def set_user
        @user = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("User with ID #{params[:id]} not found")
      end

      # Strong Parameters：ユーザーパラメータ許可設定(不正な属性の混入を防ぐ)
      def user_params
        params.require(:user).permit(:google_sub, :name, :email, :picture, :account_type)
      end

      # 共通メソッド：ユーザー情報のJSONレスポンスを生成
      def render_user_success(user, status = :ok)
        render json: user, serializer: UserSerializer, status: status
      end

      # ユーザー権限チェック：自分の情報のみアクセス可能
      def check_user_permission
        if current_user.nil?
          return handle_unauthorized("You need to sign in or sign up before continuing.")
        end
        action = action_name == 'update' ? 'update' : 'access'
        message = "You can only #{action} your own user information"
        return handle_forbidden(message) unless @user.id == current_user.id
      end

      # 重複チェック：既存ユーザーとの重複を確認
      def check_user_duplicates
        if params.dig(:user, :email).present? && User.exists?(email: params[:user][:email])
          handle_unprocessable_entity(["Email already exists"])
          return true
        end

        if params.dig(:user, :google_sub).present? && User.exists?(google_sub: params[:user][:google_sub])
          handle_unprocessable_entity(["Google account already registered"])
          return true
        end

        false
      end
    end
  end
end