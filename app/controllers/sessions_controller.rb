class SessionsController < ApplicationController
  #ライブラリの読み込み
  require "google-id-token"

  def google_auth
    auth_header = request.headers["Authorization"]

    #トークンが存在しない場合、または形式が不正な場合，unauthorizedエラーを返す
    unless auth_header&.start_with?("Bearer ")
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    #AuthorizationヘッダーからIDトークンを取り出す
    token = auth_header.split("Bearer ").last

    #トークン検証
    begin
      #IDトークンを検証するためのバリデータを作成
      validator = GoogleIDToken::Validator.new
      payload = validator.check(token, ENV["GOOGLE_CLIENT_ID"])

      sub = payload["sub"]
      email = payload["email"]
      name = payload["name"]
      picture = payload["picture"]

      #ユーザが見つかれば更新，見つからなければ作成
      user = User.find_or_create_by(google_sub: sub) do |u|
        u.name = name
        u.email = email
        u.picture = picture
      end

      render json: { message: "Login successful", user: user }
    rescue StandardError => e
      Rails.logger.error "Google Auth Error: #{e.message}"

      render json: { error: "Invalid ID token" }, status: :unauthorized
    end
  end
end