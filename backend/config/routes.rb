# frozen_string_literal: true

require "sidekiq/web"

Rails.application.routes.draw do
  # Sidekiq Web UI — development/production only
  if Rails.env.development? || Rails.env.production?
    mount Sidekiq::Web => "/sidekiq"
  end

  # Default health check
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Public endpoints (no auth required)
      resources :organizations, only: [:index]
      get "organizations/:organization_id/users", to: "organizations#users"
      post "auth/select-org", to: "auth#select_org"
      get "health", to: "health#show"

      # Authenticated endpoints
      resources :mentors, only: [:index] do
        resources :slots, only: [:index]
      end

      resources :bookings, only: [:create] do
        member do
          patch :cancel
          post :reschedule
        end
      end

      namespace :me do
        get "sessions", to: "sessions#index"
        get "mentor_sessions", to: "sessions#mentor_sessions"
      end
    end
  end
end
