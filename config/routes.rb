# config/routes.rb

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/google", to: "sessions#google_auth"

      resources :users, only: [:index, :show, :update]

      resources :groups do
        resources :tasks, only: [:index, :create]
        resources :tasks, only: [:show, :update, :destroy]
      end

      #TaskがAssignmentをネスト
      resources :tasks, only: [] do
        resources :assignments, only: [:index, :create]
      end

      #非ネストルート
      resources :assignments, only: [:show, :update, :destroy]

      resources :evaluations, only: [:create, :update, :show, :index]
    end
  end

  post "auth/google", to: "sessions#google_auth"

  get "api/test", to: "application#test"
end