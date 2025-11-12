Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # APIルーティング
  namespace :api do
    namespace :v1 do
      # Authentication
      post "auth/google", to: "sessions#google_auth"

      resources :users
      resources :groups
      resources :memberships
      resources :tasks
      resources :assignments
      resources :evaluations
      
      # Resources
      resources :users, only: [:index, :show, :update]
      resources :groups do
        resources :memberships, only: [:create, :destroy]
        resources :tasks do
          resources :assignments, only: [:create, :update, :destroy]
        end
      end
      resources :evaluations, only: [:create, :update, :show, :index]
    end
  end

  # Fallback for legacy auth endpoint
  post "auth/google", to: "sessions#google_auth"

  #テスト用エンドポイント
  get "api/test", to: "application#test"

  # Defines the root path route ("/")
  # root "posts#index"
end
