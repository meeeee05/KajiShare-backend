class ApplicationController < ActionController::API
  before_action :enforce_allowed_origin_in_production

  # 例外ハンドリングをキャッチ
  # 予期しないエラー、DB接続エラーなどは500で返す
  rescue_from StandardError, with: :handle_internal_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found  #404 レコード未発見
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing  #400 パラメータ不足
  
  # DB接続状況をJSON形式で確認
  def database_status
    begin
      # 実際にクエリを実行して接続確認
      User.connection.execute("SELECT 1")
      "connected"
    rescue
      "disconnected"    
    end
  end

  # ユーザー認証
  def authenticate_user!
    auth_header = request.headers["Authorization"]
    
    # Bearer <token>形式チェック
    unless auth_header&.start_with?("Bearer ")
      return handle_unauthorized("認証トークンが提供されていません")
    end
    
    # Bearer部分を排除→トークンのみ抽出
    token = auth_header.split("Bearer ").last
    
    # test用トークンチェック
    if (Rails.env.development? || Rails.env.test?) && token.start_with?("test_")
      case token
      when "test_admin_taro"
        @current_user = User.find_by(google_sub: "1234567890abcde")  #Admin
      when "test_member_hanako"
        @current_user = User.find_by(google_sub: "abcdef1234567890")  #Member
      when "test_nomember"
        @current_user = User.new(id: 999, google_sub: "nomember123")  #非メンバー
      else
        return handle_unauthorized("無効なテストトークン")
      end
      
      unless @current_user&.persisted?
        return handle_unauthorized("テストユーザーがDBに存在しません")
      end
      
      return
    end

    guest_user = authenticate_guest_user(token)
    return if performed?
    if guest_user
      @current_user = guest_user
      return
    end
    
    # GoogleIDToken検証
    begin
      require "google-id-token"
      validator = GoogleIDToken::Validator.new
      payload = validator.check(token, ENV["GOOGLE_CLIENT_ID"])
      
      sub = payload["sub"]
      @current_user = User.find_by(google_sub: sub)
      
      unless @current_user
        return handle_unauthorized("ユーザが見つかりません")
      end
    rescue StandardError => e
      Rails.logger.error "Token validation error: #{e.message}"

      # 期限切れトークンは再ログインを促す
      if e.message.to_s.downcase.include?("expired")
        return handle_unauthorized("セッションの有効期限が切れました。再ログインしてください。")
      end

      return handle_unauthorized("初めからやり直してください")  #セキュリティ上、詳細なエラーは返さない
    end
  end

  def current_user
    @current_user
  end

  private

    def enforce_allowed_origin_in_production
      return unless Rails.env.production?
      return unless request.path.start_with?("/api")
      return if allowed_request_origin?
      return if valid_frontend_api_secret?

      render json: {
        error: "Forbidden",
        message: "許可されていないアクセス元です",
        status: 403
      }, status: :forbidden
    end

    def allowed_request_origin?
      request_origin = request.origin
      return false if request_origin.blank?

      allowed_origins.include?(request_origin)
    end

    def valid_frontend_api_secret?
      expected_secret = ENV["FRONTEND_API_SECRET"].to_s
      return false if expected_secret.blank?

      provided_secret = request.headers["X-Frontend-Api-Secret"].to_s
      return false if provided_secret.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_secret, expected_secret)
    end

    def allowed_origins
      default_origins = [
        "http://localhost:3000",
        "http://localhost:3001",
        "http://localhost:5173",
        "http://localhost:8080"
      ]
      configured_origins = ENV.fetch("CORS_ORIGINS", ENV.fetch("FRONTEND_URL", "")).split(",").map(&:strip).reject(&:blank?)

      default_origins + configured_origins
    end

    def guest_token_verifier
      Rails.application.message_verifier(:guest_auth)
    end

    def authenticate_guest_user(token)
      payload = guest_token_verifier.verified(token)
      return nil unless payload.is_a?(Hash)

      token_type = payload["type"] || payload[:type]
      return nil unless token_type == "guest"

      expires_at = (payload["exp"] || payload[:exp]).to_i
      if expires_at <= Time.current.to_i
        handle_unauthorized("ゲスト利用期限が切れました。再度ログインしてください。")
        return nil
      end

      user_id = payload["user_id"] || payload[:user_id]
      user = User.find_by(id: user_id, account_type: "guest")
      unless user
        handle_unauthorized("ゲスト利用期限が切れました。再度ログインしてください。")
        return nil
      end

      user
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def localized_message(message, fallback)
      return fallback if message.blank?
      return message unless message.is_a?(String)

      message.ascii_only? ? fallback : message
    end

    # 400: Bad Request
    def handle_parameter_missing(exception)
      render json: {
        error: "Bad Request",
        message: "必要なパラメータが不足しています: #{exception.param}",
        status: 400
      }, status: :bad_request
    end

    # 401: Unauthorized
    def handle_unauthorized(message = "認証に失敗しました")
      render json: {
        error: "Unauthorized",
        message: message,
        status: 401
      }, status: :unauthorized
    end

    # 403: Forbidden
    def handle_forbidden(message = "アクセス権限がありません")
      render json: {
        error: "Forbidden",
        message: message,
        status: 403
      }, status: :forbidden
    end

    # 404: Not Found
    def handle_not_found(message_or_exception = nil)
      message = case message_or_exception
                when String
                  message_or_exception
                when Exception
                  message_or_exception.message
                else
                  "指定されたリソースが見つかりません"
                end

      render json: {
        error: "Not Found",
        message: message,
        status: 404
      }, status: :not_found
    end

    # 422: Unprocessable Entity
    def handle_unprocessable_entity(errors)
      render json: {
        error: "Unprocessable Entity",
        message: "入力内容に誤りがあります",
        errors: errors,
        status: 422
      }, status: :unprocessable_entity
    end

    # 500: Internal Server Error
    def handle_internal_error(exception_or_message)
      case exception_or_message
      when String
        message = exception_or_message
        Rails.logger.error "Internal Server Error: #{message}"
      when Exception
        message = exception_or_message.message
        Rails.logger.error "Internal Server Error: #{message}"
        Rails.logger.error exception_or_message.backtrace.join("\n")
      else
        message = "予期しないエラーが発生しました"
        Rails.logger.error "Internal Server Error: #{message}"
      end

      render json: {
        error: "Internal Server Error",
        message: Rails.env.production? ? "サーバーで問題が発生しました。時間をおいて再度お試しください。" : message,
        status: 500
      }, status: :internal_server_error
    end
end
