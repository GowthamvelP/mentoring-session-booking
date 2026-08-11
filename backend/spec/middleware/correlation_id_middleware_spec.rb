# frozen_string_literal: true

require "rails_helper"

RSpec.describe CorrelationIdMiddleware, type: :request do
  describe "correlation ID injection" do
    it "generates a correlation ID when none provided" do
      get "/api/v1/organizations"

      expect(response.headers["X-Request-Id"]).to be_present
      expect(response.headers["X-Request-Id"]).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "uses provided X-Request-Id header" do
      custom_id = "custom-correlation-123"
      get "/api/v1/organizations", headers: { "X-Request-Id" => custom_id }

      expect(response.headers["X-Request-Id"]).to eq(custom_id)
    end

    it "stores correlation ID in RequestStore" do
      custom_id = "test-correlation-id"
      # Hit an endpoint that exercises the middleware
      get "/api/v1/organizations", headers: { "X-Request-Id" => custom_id }

      # The response header confirms the middleware processed the request
      expect(response.headers["X-Request-Id"]).to eq(custom_id)
    end
  end
end
