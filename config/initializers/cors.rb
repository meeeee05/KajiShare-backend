# config/initializers/cors.rb
# corsの設定
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    default_origins = [
      "http://localhost:3000",
      "http://localhost:3001",
      "http://localhost:5173",
      "http://localhost:8080"
    ]
    configured_origins = ENV.fetch("CORS_ORIGINS", ENV.fetch("FRONTEND_URL", "")).split(",").map(&:strip).reject(&:blank?)

    origins(*default_origins, *configured_origins)

    resource "*",
      headers: :any,

      #許可するHTTPメソッド
      methods: [:get, :post, :put, :patch, :delete, :options, :head],

      #Cookie認証を有効にする
      credentials: true
  end
end
