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

      #タスクとアサインメントの関係
      resources :tasks, only: [:index, :show] do
        resources :assignments, only: [:index, :create]
      end
      
      #独立したリソース
      resources :assignments, only: [:show, :update, :destroy]
      resources :memberships, only: [:index, :show, :update] do
        member do
          patch :change_role
        end
      end
      resources :evaluations, only: [:create, :update, :show, :index, :destroy]
    end
  end

  post "auth/google", to: "sessions#google_auth"

  get "api/test", to: "application#test"
end