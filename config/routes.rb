# config/routes.rb

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/google", to: "sessions#google_auth"

      resources :users, only: [:index, :show, :update]

      resources :groups do
        resources :tasks, only: [:index, :create, :show, :update, :destroy]
        resources :memberships, only: [:index, :create, :destroy]
      end

      #独立したリソース
      resources :tasks, only: [:index, :show]
      resources :assignments, only: [:index, :show, :update, :destroy]
      resources :memberships, only: [:index, :show, :update]
      resources :evaluations, only: [:create, :update, :show, :index]
    end
  end

  post "auth/google", to: "sessions#google_auth"

  get "api/test", to: "application#test"
end