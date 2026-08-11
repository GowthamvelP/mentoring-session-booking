# frozen_string_literal: true

class Rack::Attack
  # Use Redis as the cache store for distributed state
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  )

  # === Throttles ===

  # Limit booking creation to 10 requests per minute per user
  throttle("bookings/create", limit: 10, period: 1.minute) do |req|
    if req.path == "/api/v1/bookings" && req.post?
      req.env["HTTP_X_USER_ID"]
    end
  end

  # Limit reschedule to 5 requests per minute per user
  throttle("bookings/reschedule", limit: 5, period: 1.minute) do |req|
    if req.path.match?(%r{/api/v1/bookings/.+/reschedule}) && req.post?
      req.env["HTTP_X_USER_ID"]
    end
  end

  # Limit slot listing to 100 requests per minute per user
  throttle("slots/index", limit: 100, period: 1.minute) do |req|
    if req.path.match?(%r{/api/v1/mentors/.+/slots}) && req.get?
      req.env["HTTP_X_USER_ID"]
    end
  end

  # === Response ===
  # Return 429 with Retry-After header
  self.throttled_responder = lambda do |env|
    retry_after = (env["rack.attack.match_data"] || {})[:period]
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [{ error: "Rate limit exceeded", details: { retry_after: retry_after } }.to_json]
    ]
  end
end
