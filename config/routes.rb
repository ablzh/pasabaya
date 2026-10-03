Rails.application.routes.draw do
  resources :users, only: [ :show ]
  get "trips", to: "users#trips", as: :trips
  get "rides/from-:origin_slug-to-:destination_slug", to: "ride_posts#index", as: :route_rides
  resources :ride_posts, path: "rides" do
    member do
      patch :cancel
    end
    resources :bookings, only: [ :create ]
    resources :chat_messages, only: [ :create ]
    resources :reviews, only: [ :new, :create ], controller: "trip_reviews"
  end

  resources :bookings, only: [ :show ] do
    member do
      patch :accept
      patch :decline
      patch :cancel
    end
  end

  resources :notifications, only: [ :index, :show ] do
    collection do
      patch :mark_all_as_read
    end
    member do
      patch :mark_as_read
    end
  end

  resources :communities, only: [ :index, :show ] do
    resources :memberships, only: [ :create, :destroy ], controller: "community_memberships"
  end
  get "community_memberships/verify/:token", to: "community_memberships#verify", as: :verify_community_membership

  resource :session
  resources :passwords, param: :token

  namespace :settings do
    resource :profile, only: [ :show, :update ]
    resource :email, only: [ :update ]
    resource :password, only: [ :update ]
    resource :user, only: [ :destroy ]
  end

  namespace :email do
    resources :confirmations, param: :token, only: [ :show ]
  end

  get "sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: { format: :xml }
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
