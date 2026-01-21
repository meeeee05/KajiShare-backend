class ApplicationController < ActionController::API
  # 例外ハンドリングをキャッチ
  # 予期しないエラー、DB接続エラーなどは500で返す
  rescue_from StandardError, with: :handle_internal_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found  #404 レコード未発見
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing  #400 パラメータ不足
  
  # test用エンドポイント
  def test
    render json: { 
      message: "KajiShare API is working!", 
      timestamp: Time.current,
      database: database_status
    }
  end

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
      return handle_unauthorized("No authentication token provided")
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
        return handle_unauthorized("Invalid test token")
      end
      
      unless @current_user&.persisted?
        return handle_unauthorized("Test user not found in database")
      end
      
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
        return handle_unauthorized("User not found. Please register first.")
      end
    rescue StandardError => e
      Rails.logger.error "Token validation error: #{e.message}"
      return handle_unauthorized("Invalid or expired authentication token")
    end
  end

  def current_user
    @current_user
  end

  private

    # 400: Bad Request
  def handle_parameter_missing(exception)
    render json: { 
      error: "Bad Request", 
      message: "Required parameter missing: #{exception.param}",
      status: 400
    }, status: :bad_request
    end

  # 401: Unauthorized
  def handle_unauthorized(message = "Unauthorized access")
    render json: { 
      error: "Unauthorized", 
      message: message,
      status: 401
    }, status: :unauthorized
  end

  # 403: Forbidden
  def handle_forbidden(message = "Access denied")
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
                "Resource not found"
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
      message: "Validation failed",
      errors: errors,
      status: 422
    }, status: :unprocessable_entity
  end

  # 500: Internal Server Error
  def handle_internal_error(exception_or_message)
    case exception_or_message
    # 引数が文字列の場合
    when String
      message = exception_or_message
      Rails.logger.error "Internal Server Error: #{message}"
    when Exception
      message = exception_or_message.message
      Rails.logger.error "Internal Server Error: #{message}"
      Rails.logger.error exception_or_message.backtrace.join("\n")
    else
      message = "Something went wrong"
      Rails.logger.error "Internal Server Error: #{message}"
    end
    
    render json: { 
      error: "Internal Server Error", 
      message: Rails.env.production? ? "Something went wrong" : message,
      status: 500
    }, status: :internal_server_error
  end
end