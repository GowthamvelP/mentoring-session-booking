# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions API", type: :request do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }

  describe "GET /api/v1/me/sessions" do
    let(:headers) { { "X-User-Id" => member.id, "X-Org-Id" => organization.id } }

    before do
      slot = create(:slot, :booked, mentor: mentor, organization: organization)
      create(:booking, slot: slot, member: member, organization: organization)
    end

    it "returns member's bookings with mentor details" do
      get "/api/v1/me/sessions", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].first).to include("id", "status", "slot")
      expect(json["data"].first["mentor"]).to include("id", "name")
      expect(json["meta"]).to include("current_page", "total_count")
    end

    it "returns 401 without auth" do
      get "/api/v1/me/sessions"
      expect(response).to have_http_status(:unauthorized)
    end

    it "only returns bookings for the current member" do
      other_member = create(:user, :member, organization: organization)
      other_slot = create(:slot, :booked, mentor: mentor, organization: organization,
                          start_time: 4.days.from_now.beginning_of_hour,
                          end_time: 4.days.from_now.beginning_of_hour + 1.hour)
      create(:booking, slot: other_slot, member: other_member, organization: organization)

      get "/api/v1/me/sessions", headers: headers

      json = JSON.parse(response.body)
      expect(json["data"].length).to eq(1)
    end
  end

  describe "GET /api/v1/me/mentor_sessions" do
    let(:headers) { { "X-User-Id" => mentor.id, "X-Org-Id" => organization.id } }

    before do
      slot = create(:slot, :booked, mentor: mentor, organization: organization)
      create(:booking, slot: slot, member: member, organization: organization)
    end

    it "returns mentor's sessions with member details" do
      get "/api/v1/me/mentor_sessions", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].first["member"]).to include("id", "name", "email")
    end

    it "returns 403 for non-mentor user" do
      member_headers = { "X-User-Id" => member.id, "X-Org-Id" => organization.id }
      get "/api/v1/me/mentor_sessions", headers: member_headers

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without auth" do
      get "/api/v1/me/mentor_sessions"
      expect(response).to have_http_status(:unauthorized)
    end

    it "includes pagination metadata" do
      get "/api/v1/me/mentor_sessions", headers: headers

      json = JSON.parse(response.body)
      expect(json["meta"]).to include("current_page", "total_pages", "total_count")
    end
  end
end
