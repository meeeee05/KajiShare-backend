# config/routes.rb

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/google", to: "sessions#google_auth"
      post "groups/join", to: "memberships#create"

      get "users/me", to: "users#index"
      resources :users, only: [:index, :show, :create, :update, :destroy]

      resources :groups do
        member do
          post :leave
          delete :leave
          delete "members/me", to: "groups#leave"
        end
        resources :tasks, only: [:index, :create, :show, :update, :destroy]
        resources :recurring_tasks, only: [:index, :create]
        resources :memberships, only: [:index, :create, :destroy]
      end

      #タスクとアサインメントの関係
      resources :tasks, only: [:index, :show] do
        resources :assignments, only: [:index, :create]
      end
      # 直下でタスクのshow/update/destroyも許可
      resources :tasks, only: [:show, :update, :destroy]
      resources :recurring_tasks, only: [:show, :update, :destroy]
      
      #独立したリソース
      resources :assignments, only: [:show, :update, :destroy] do
        resources :evaluations, only: [:create]
      end
      resources :memberships, only: [:index, :show, :update, :create, :destroy] do
        member do
          patch :change_role
        end
      end
      resources :evaluations, only: [:create, :update, :show, :index, :destroy]
      resources :notifications, only: [:index]
    end
  end

  post "auth/google", to: "sessions#google_auth"

  get "api/test", to: "application#test"
end