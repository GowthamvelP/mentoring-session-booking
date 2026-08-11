require "rails_helper"

RSpec.describe "Health API", type: :request do
  describe "GET /api/v1/health" do
    it "returns a health check response" do
      get "/api/v1/health"

      # Health endpoint should always respond (even if some services are down)
      expect(response).to have_http_status(:ok).or have_http_status(:service_unavailable)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("ok").or eq("degraded")
      expect(json["checks"]["database"]["status"]).to eq("connected")
    end

    it "does not require authentication" do
      get "/api/v1/health"
      expect(response).not_to have_http_status(:unauthorized)
    end

    it "includes timestamp in response" do
      get "/api/v1/health"

      json = JSON.parse(response.body)
      expect(json["timestamp"]).to be_present
    end

    it "includes all dependency checks" do
      get "/api/v1/health"

      json = JSON.parse(response.body)
      expect(json["checks"]).to have_key("database")
      expect(json["checks"]).to have_key("redis")
      expect(json["checks"]).to have_key("sidekiq")
    end
  end
end
