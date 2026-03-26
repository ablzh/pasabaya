Rails.application.routes.draw do
  get "privacy", to: "pages#privacy"

  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"
  resources :subscribers, only: [ :create ]
end
