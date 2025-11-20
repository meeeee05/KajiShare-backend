class ApplicationController < ActionController::API

  #test用エンドポイント
  def test
    render json: { 
      message: "KajiShare API is working!", 
      timestamp: Time.current,
      database: database_status
    }
  end

#DB接続状況をJSON形式で確認
  def database_status
    begin
      #実際にクエリを実行して接続確認
      User.connection.execute("SELECT 1")
      "connected"
    rescue
      "disconnected"    
    end
  end

  def authenticate_user!
    auth_header = request.headers["Authorization"]
    
    unless auth_header&.start_with?("Bearer ")
      return render json: { error: "Unauthorized - No token provided" }, status: :unauthorized
    end
    
    token = auth_header.split("Bearer ").last
    
    #テスト用トークンチェック
    if Rails.env.development? && token.start_with?("test_")
      case token
      when "test_admin_taro"
        @current_user = User.find_by(google_sub: "1234567890abcde")  # Taro (Admin)
      when "test_member_hanako"
        @current_user = User.find_by(google_sub: "abcdef1234567890")  # Hanako (Member)
      when "test_nonmember"
        @current_user = User.new(id: 999, google_sub: "nonmember123")  # 非メンバー
      else
        return render json: { error: "Invalid test token" }, status: :unauthorized
      end
      
      unless @current_user&.persisted?
        return render json: { error: "Test user not found" }, status: :unauthorized
      end
      
      return
    end
    
    #Google ID Token検証
    begin
      require "google-id-token"
      validator = GoogleIDToken::Validator.new
      payload = validator.check(token, ENV["GOOGLE_CLIENT_ID"])
      
      sub = payload["sub"]
      @current_user = User.find_by(google_sub: sub)
      
      unless @current_user
        render json: { error: "User not found. Please register first." }, status: :unauthorized
      end
    rescue StandardError => e
      Rails.logger.error "Token validation error: #{e.message}"
      render json: { error: "Invalid token" }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end
end