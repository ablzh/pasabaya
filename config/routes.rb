Rails.application.routes.draw do
  root "pages#home"
  resources :subscribers, only: [:create]
end