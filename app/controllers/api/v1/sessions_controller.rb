class Api::V1::SessionsController < Api::V1::BaseController
  require "google-id-token"

  def google_auth
    auth_header = request.headers["Authorization"]

    unless auth_header&.start_with?("Bearer ")
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    token = auth_header.split("Bearer ").last

    begin
      validator = GoogleIDToken::Validator.new
      payload = validator.check(token, ENV["GOOGLE_CLIENT_ID"])

      sub = payload["sub"]
      email = payload["email"]
      name = payload["name"]
      picture = payload["picture"]

      user = User.find_or_create_by(google_sub: sub) do |u|
        u.name = name
        u.email = email
        u.picture = picture
      end

      render_success({ user: user }, "Login successful")
    rescue StandardError => e
      Rails.logger.error "Google Auth Error: #{e.message}"
      render json: { error: "Invalid ID token" }, status: :unauthorized
    end
  end
end
