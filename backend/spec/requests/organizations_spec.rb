# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations API", type: :request do
  let!(:org1) { create(:organization, name: "TechMentor") }
  let!(:org2) { create(:organization, name: "Acme") }

  describe "GET /api/v1/organizations" do
    it "returns all organizations ordered by name" do
      get "/api/v1/organizations"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to be >= 2
      names = json.map { |o| o["name"] }
      expect(names).to include("Acme", "TechMentor")
      expect(names).to eq(names.sort) # alphabetical order
      expect(json.first).to include("id", "name", "timezone")
    end

    it "does not require authentication" do
      get "/api/v1/organizations"
      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/organizations/:organization_id/users" do
    let!(:member) { create(:user, :member, organization: org1) }
    let!(:mentor) { create(:user, :mentor, organization: org1) }

    it "returns all users for the organization" do
      get "/api/v1/organizations/#{org1.id}/users"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
      expect(json.first).to include("id", "name", "email", "role")
    end

    it "returns 404 for invalid organization" do
      get "/api/v1/organizations/#{SecureRandom.uuid}/users"
      expect(response).to have_http_status(:not_found)
    end

    it "does not return users from other organizations" do
      create(:user, organization: org2)

      get "/api/v1/organizations/#{org1.id}/users"

      json = JSON.parse(response.body)
      expect(json.length).to eq(2) # only org1 users
    end
  end
end
