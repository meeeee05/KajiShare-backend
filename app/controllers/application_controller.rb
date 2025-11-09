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
end
