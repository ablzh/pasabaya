Rails.application.routes.draw do
  resources :users, only: [ :show ]
  resource :profile, only: [ :edit, :update ]
  # resource :dashboard, only: [ :show ]
  resources :ride_posts, path: "rides"
  resource :session
  resources :passwords, param: :token

  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"

  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"

  get "up" => "rails/health#show", as: :rails_health_check
  
  root "pages#home"
  resources :subscribers, only: [ :create ] do
    member do
      get :unsubscribe
    end
  end
end
