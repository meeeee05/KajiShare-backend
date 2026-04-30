class Api::V1::SessionsController < Api::V1::BaseController
  # require "google-id-token"
  require 'googleauth/id_tokens/verifier'

  GUEST_TOKEN_TTL = 1.hour

  def google_auth
    auth_header = request.headers["Authorization"]

    unless auth_header&.start_with?("Bearer ")
      return render json: { error: "認証エラー", message: "認証情報が不足しています" }, status: :unauthorized
    end

    token = auth_header.split("Bearer ").last

    begin
      # validator = GoogleIDToken::Validator.new
      # payload = validator.check(token, ENV["GOOGLE_CLIENT_ID"])
      payload = Google::Auth::IDTokens.verify_oidc(token, aud: ENV["GOOGLE_CLIENT_ID"])

      sub = payload["sub"]
      email = payload["email"]
      name = payload["name"]
      picture = payload["picture"]

      if sub.blank?
        Rails.logger.warn "Google Auth Error: sub is missing"
        return render json: { error: "認証エラー", message: "IDトークンが無効です" }, status: :unauthorized
      end

      user = User.find_or_create_by(google_sub: sub) do |u|
        u.name = name
        u.email = email
        u.picture = picture
        u.account_type = 'user'  # デフォルトでuserタイプに設定
      end

      render_success({ user: user })
    rescue StandardError => e
      Rails.logger.error "Google Auth Error: #{e.message}"
      render json: { error: "認証エラー", message: "IDトークンが無効です" }, status: :unauthorized
    end
  end

  def guest_auth
    user = build_guest_user

    if user.save
      token_expires_at = GUEST_TOKEN_TTL.from_now
      token = guest_token_verifier.generate(
        {
          type: "guest",
          user_id: user.id,
          exp: token_expires_at.to_i
        }
      )

      render_success(
        {
          user: user,
          token: token,
          token_type: "Bearer",
          expires_at: token_expires_at.iso8601
        },
        "ゲストログインに成功しました"
      )
    else
      handle_unprocessable_entity(user.errors.full_messages)
    end
  rescue StandardError => e
    Rails.logger.error "Guest Auth Error: #{e.message}"
    handle_internal_error("ゲストログイン中にエラーが発生しました")
  end

  private

  def build_guest_user
    random = SecureRandom.hex(8)
    User.new(
      google_sub: "guest_#{SecureRandom.uuid}",
      name: guest_name,
      email: "guest_#{random}@example.local",
      picture: nil,
      account_type: "guest"
    )
  end

  def guest_name
    params[:name].presence || params.dig(:guest, :name).presence || "ゲストユーザー"
  end
end
