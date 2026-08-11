# frozen_string_literal: true

# Redis configuration for cache + Sidekiq
REDIS_URL = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
