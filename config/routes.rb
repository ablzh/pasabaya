Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  get "privacy", to: "pages#privacy"

  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"
  resources :subscribers, only: [ :create ] do
    member do
      get :unsubscribe
    end
  end
end
