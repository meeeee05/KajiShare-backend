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