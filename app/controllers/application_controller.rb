class ApplicationController < ActionController::API

  #test用エンドポイント
  def test
    render json: { 
      message: "KajiShare API is working!", 
      timestamp: Time.current,
      database: database_status
    }
  end

  private

  #DB接続条項をJSON形式で確認
  def database_status
    begin
      User.connection.active? ? "connected" : "disconnected"
    rescue
      "error"
    end
  end
end
