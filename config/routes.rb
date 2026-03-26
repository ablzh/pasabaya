Rails.application.routes.draw do
  get "privacy", to: "pages#privacy"

  root "pages#home"
  resources :subscribers, only: [:create]
end
