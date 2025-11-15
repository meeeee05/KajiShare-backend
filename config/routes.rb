Rails.application.routes.draw do
  # Healthcheck
  get "up" => "rails/health#show", as: :rails_health_check

  # APIルーティング
  namespace :api do
    namespace :v1 do
      # Authentication
      post "auth/google", to: "sessions#google_auth"
      
      # User management
      resources :users, only: [:index, :show, :update]
      
      # Groups and nested resources
      resources :groups do
        resources :tasks, only: [:index, :create, :show, :update, :destroy]
      end

      # Standalone resources
      resources :tasks, only: [:index, :show]  # 全タスクの一覧・詳細用
      #resources :assignments, only: [:show, :index]
      resources :assignments
      resources :evaluations, only: [:create, :update, :show, :index]
    end
  end

  # Fallback for legacy auth endpoint
  post "auth/google", to: "sessions#google_auth"

  # Test endpoint
  get "api/test", to: "application#test"
end