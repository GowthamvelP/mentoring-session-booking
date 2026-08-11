# frozen_string_literal: true

# Configure CORS to allow the React frontend to make API requests.
# In production, restrict origins to the actual frontend domain.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"  # Development: allow all origins. Production: restrict to frontend URL.

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["X-Request-Id"]
  end
end
