# frozen_string_literal: true

require "sidekiq"
require "sidekiq/web"

REDIS_URL = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = {
    url: REDIS_URL,
    pool_timeout: 5,
    size: ENV.fetch("SIDEKIQ_CONCURRENCY", 10).to_i + 5  # concurrency + buffer
  }

  # Server middleware for logging and error tracking
  config.server_middleware do |chain|
    # Future: Add Sentry, Datadog, or custom error tracking middleware
  end

  # Death handler — log when a job exhausts all retries
  config.death_handlers << ->(job, _ex) do
    Rails.logger.error(
      event: "sidekiq_job_dead",
      job_class: job["class"],
      job_id: job["jid"],
      args: job["args"],
      queue: job["queue"],
      error: job["error_message"]
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: REDIS_URL,
    pool_timeout: 5,
    size: 5  # Client pool smaller than server
  }
end

# Sidekiq Web UI — basic protection
if defined?(Sidekiq::Web)
  if Rails.env.production?
    Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, ENV.fetch("SIDEKIQ_WEB_USER", "admin")) &
        ActiveSupport::SecurityUtils.secure_compare(password, ENV.fetch("SIDEKIQ_WEB_PASSWORD", "admin"))
    end
  end
end
