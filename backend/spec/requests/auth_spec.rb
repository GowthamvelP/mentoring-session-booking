# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth API", type: :request do
  let(:org) { create(:organization) }
  let(:user) { create(:user, organization: org) }

  describe "POST /api/v1/auth/select-org" do
    it "returns organization and user details" do
      post "/api/v1/auth/select-org", params: { organization_id: org.id, user_id: user.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["organization"]["id"]).to eq(org.id)
      expect(json["user"]["id"]).to eq(user.id)
      expect(json["user"]["name"]).to eq(user.name)
    end

    it "returns 404 for invalid organization" do
      post "/api/v1/auth/select-org", params: { organization_id: SecureRandom.uuid, user_id: user.id }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for invalid user" do
      post "/api/v1/auth/select-org", params: { organization_id: org.id, user_id: SecureRandom.uuid }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for user in different org" do
      other_org = create(:organization, name: "Other Org")
      post "/api/v1/auth/select-org", params: { organization_id: other_org.id, user_id: user.id }
      expect(response).to have_http_status(:not_found)
    end
  end
end
