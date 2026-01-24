# config/routes.rb

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/google", to: "sessions#google_auth"

      resources :users, only: [:index, :show, :create, :update]

      resources :groups do
        resources :tasks, only: [:index, :create, :show, :update, :destroy]
        resources :memberships, only: [:index, :create, :destroy]
      end

      #タスクとアサインメントの関係
      resources :tasks, only: [:index, :show] do
        resources :assignments, only: [:index, :create]
      end
      # 直下でタスクのshow/update/destroyも許可
      resources :tasks, only: [:show, :update, :destroy]
      
      #独立したリソース
      resources :assignments, only: [:show, :update, :destroy]
      resources :memberships, only: [:index, :show, :update, :create, :destroy] do
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