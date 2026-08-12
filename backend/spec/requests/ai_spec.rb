# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AI API", type: :request do
  let(:organization) { create(:organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:headers) { { "X-User-Id" => member.id, "X-Org-Id" => organization.id } }

  describe "GET /api/v1/ai/context" do
    it "returns system context without authentication" do
      get "/api/v1/ai/context"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["system"]["name"]).to eq("MentorBook Mentoring Booking")
      expect(json["system"]["version"]).to eq("1.0.0")
      expect(json["schema"]).to have_key("organizations")
      expect(json["schema"]).to have_key("users")
      expect(json["schema"]).to have_key("slots")
      expect(json["schema"]).to have_key("bookings")
      expect(json["conventions"]).to have_key("write_path")
      expect(json["endpoints"]).to be_an(Array)
      expect(json["ai_features"]).to include("ai_context_api" => true, "mcp_server" => true)
    end
  end

  describe "GET /api/v1/ai/mcp/tools" do
    it "returns tool definitions" do
      get "/api/v1/ai/mcp/tools", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["tools"]).to be_an(Array)
      tool_names = json["tools"].map { |t| t["name"] }
      expect(tool_names).to include("list_mentors", "list_slots", "book_slot", "cancel_booking", "my_sessions")
    end

    it "includes input schemas for each tool" do
      get "/api/v1/ai/mcp/tools", headers: headers

      json = JSON.parse(response.body)
      json["tools"].each do |tool|
        expect(tool).to have_key("name")
        expect(tool).to have_key("description")
        expect(tool).to have_key("input_schema")
      end
    end
  end

  describe "POST /api/v1/ai/mcp/call" do
    context "list_mentors" do
      it "returns mentors in the organization" do
        mentor # ensure mentor exists

        post "/api/v1/ai/mcp/call", params: { name: "list_mentors", arguments: {} }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["mentors"]).to be_an(Array)
        expect(json["mentors"].first["id"]).to eq(mentor.id)
      end
    end

    context "list_slots" do
      let!(:slot) { create(:slot, mentor: mentor, organization: organization, status: :available) }

      it "returns available slots for a mentor" do
        post "/api/v1/ai/mcp/call",
             params: { name: "list_slots", arguments: { mentor_id: mentor.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["mentor"]["id"]).to eq(mentor.id)
        expect(json["slots"]).to be_an(Array)
      end
    end

    context "book_slot" do
      let!(:slot) { create(:slot, mentor: mentor, organization: organization, status: :available) }

      it "books a slot via MCP tool call" do
        post "/api/v1/ai/mcp/call",
             params: { name: "book_slot", arguments: { slot_id: slot.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["booking"]["status"]).to eq("confirmed")
      end
    end

    context "cancel_booking" do
      let!(:slot) { create(:slot, :booked, mentor: mentor, organization: organization, start_time: 2.days.from_now.beginning_of_hour, end_time: 2.days.from_now.beginning_of_hour + 1.hour) }
      let!(:booking) { create(:booking, slot: slot, member: member, organization: organization, status: :confirmed) }

      it "cancels a booking via MCP tool call" do
        post "/api/v1/ai/mcp/call",
             params: { name: "cancel_booking", arguments: { booking_id: booking.id, reason: "Schedule conflict" } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end
    end

    context "my_sessions" do
      it "returns the user's sessions" do
        post "/api/v1/ai/mcp/call",
             params: { name: "my_sessions", arguments: {} },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["sessions"]).to be_an(Array)
      end
    end

    context "unknown tool" do
      it "returns an error for unknown tools" do
        post "/api/v1/ai/mcp/call",
             params: { name: "unknown_tool", arguments: {} },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Unknown tool")
      end
    end
  end
end
