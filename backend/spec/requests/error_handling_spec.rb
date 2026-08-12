# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Error handling", type: :request do
  let(:organization) { create(:organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:headers) { { "X-User-Id" => member.id, "X-Org-Id" => organization.id } }

  describe "RecordNotFound handling" do
    it "returns 404 with error structure for missing booking" do
      patch "/api/v1/bookings/#{SecureRandom.uuid}/cancel", headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Resource not found")
      expect(json["details"]).to have_key("resource")
    end

    it "returns 404 for non-existent mentor slots" do
      get "/api/v1/mentors/#{SecureRandom.uuid}/slots", headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Resource not found")
    end
  end

  describe "RecordInvalid handling" do
    it "returns 422 when a model validation fails during save!" do
      # Stub the user model to raise RecordInvalid when update! is called
      # by simulating a validation failure on the timezone endpoint
      allow_any_instance_of(User).to receive(:update!).and_raise(
        ActiveRecord::RecordInvalid.new(member)
      )

      patch "/api/v1/me/timezone", params: { timezone: "America/New_York" }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Validation failed")
    end
  end

  describe "NoTenantSet handling" do
    it "returns 401 when ActsAsTenant raises NoTenantSet" do
      # Simulate the NoTenantSet error by stubbing the tenant setting
      allow(ActsAsTenant).to receive(:current_tenant=).and_call_original
      allow(User).to receive(:mentors).and_raise(ActsAsTenant::Errors::NoTenantSet)

      get "/api/v1/mentors", headers: headers
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Organization context required")
    end
  end

  describe "Authenticatable#current_organization" do
    it "makes organization accessible via authenticated request" do
      # Any successful request verifies current_organization is accessible
      get "/api/v1/mentors", headers: headers
      expect(response).to have_http_status(:ok)
    end
  end
end
