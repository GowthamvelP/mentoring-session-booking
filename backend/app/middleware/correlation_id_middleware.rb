# frozen_string_literal: true

# Generates a unique correlation ID for each request and stores it
# in RequestStore for access throughout the request lifecycle.
# Returns the ID in the X-Request-Id response header.
class CorrelationIdMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    correlation_id = env["HTTP_X_REQUEST_ID"] || SecureRandom.uuid
    RequestStore.store[:correlation_id] = correlation_id

    # Also store user/org IDs for logging
    RequestStore.store[:user_id] = env["HTTP_X_USER_ID"]
    RequestStore.store[:org_id] = env["HTTP_X_ORG_ID"]

    status, headers, body = @app.call(env)

    headers["X-Request-Id"] = correlation_id
    [status, headers, body]
  end
end
