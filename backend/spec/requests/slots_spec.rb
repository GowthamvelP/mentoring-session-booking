# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Slots API", type: :request do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:headers) { { "X-User-Id" => member.id, "X-Org-Id" => organization.id } }

  before do
    # Create slots across different dates
    create(:slot, mentor: mentor, organization: organization,
           start_time: 1.day.from_now.beginning_of_hour,
           end_time: 1.day.from_now.beginning_of_hour + 1.hour)
    create(:slot, mentor: mentor, organization: organization,
           start_time: 3.days.from_now.beginning_of_hour,
           end_time: 3.days.from_now.beginning_of_hour + 1.hour)
    create(:slot, :booked, mentor: mentor, organization: organization,
           start_time: 2.days.from_now.beginning_of_hour,
           end_time: 2.days.from_now.beginning_of_hour + 1.hour)
  end

  describe "GET /api/v1/mentors/:mentor_id/slots" do
    it "returns available future slots for the mentor" do
      get "/api/v1/mentors/#{mentor.id}/slots", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      statuses = json["data"].map { |s| s["status"] }
      expect(statuses).to all(eq("available"))
    end

    it "returns slots in ISO 8601 format" do
      get "/api/v1/mentors/#{mentor.id}/slots", headers: headers

      json = JSON.parse(response.body)
      expect(json["data"].first["start_time"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "respects date range parameters" do
      start_date = Date.current.iso8601
      end_date = (Date.current + 2.days).iso8601

      get "/api/v1/mentors/#{mentor.id}/slots",
          params: { start_date: start_date, end_date: end_date },
          headers: headers

      json = JSON.parse(response.body)
      expect(json["meta"]["start_date"]).to eq(start_date)
      expect(json["meta"]["end_date"]).to eq(end_date)
    end

    it "returns 404 for non-existent mentor" do
      get "/api/v1/mentors/#{SecureRandom.uuid}/slots", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without auth" do
      get "/api/v1/mentors/#{mentor.id}/slots"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with invalid organization ID" do
      bad_headers = { "X-User-Id" => member.id, "X-Org-Id" => SecureRandom.uuid }
      get "/api/v1/mentors/#{mentor.id}/slots", headers: bad_headers
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Invalid organization")
    end

    it "returns 401 with invalid user ID" do
      bad_headers = { "X-User-Id" => SecureRandom.uuid, "X-Org-Id" => organization.id }
      get "/api/v1/mentors/#{mentor.id}/slots", headers: bad_headers
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Invalid user")
    end

    it "returns 401 with only X-User-Id header" do
      get "/api/v1/mentors/#{mentor.id}/slots", headers: { "X-User-Id" => member.id }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with only X-Org-Id header" do
      get "/api/v1/mentors/#{mentor.id}/slots", headers: { "X-Org-Id" => organization.id }
      expect(response).to have_http_status(:unauthorized)
    end

    it "includes metadata" do
      get "/api/v1/mentors/#{mentor.id}/slots", headers: headers

      json = JSON.parse(response.body)
      expect(json["meta"]).to include("mentor_id", "start_date", "end_date")
    end

    it "handles invalid date parameters gracefully" do
      get "/api/v1/mentors/#{mentor.id}/slots",
          params: { start_date: "not-a-date", end_date: "invalid" },
          headers: headers

      expect(response).to have_http_status(:ok)
      # Falls back to default dates when parsing fails
      json = JSON.parse(response.body)
      expect(json["meta"]).to include("start_date", "end_date")
    end
  end
end
