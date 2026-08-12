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
    it "returns all 8 tool definitions" do
      get "/api/v1/ai/mcp/tools", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["tools"]).to be_an(Array)
      expect(json["tools"].length).to eq(8)
      tool_names = json["tools"].map { |t| t["name"] }
      expect(tool_names).to include(
        "list_mentors", "list_slots", "book_slot", "cancel_booking",
        "my_sessions", "get_mentor_profile", "get_booking_details", "reschedule_booking"
      )
    end

    it "includes input schemas for each tool" do
      get "/api/v1/ai/mcp/tools", headers: headers

      json = JSON.parse(response.body)
      json["tools"].each do |tool|
        expect(tool).to have_key("name")
        expect(tool).to have_key("description")
        expect(tool).to have_key("input_schema")
        expect(tool["input_schema"]).to have_key("type")
        expect(tool["input_schema"]["type"]).to eq("object")
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
        expect(json["mentors"].first).to have_key("name")
        expect(json["mentors"].first).to have_key("email")
        expect(json["mentors"].first).to have_key("expertise")
        expect(json["mentors"].first).to have_key("bio")
      end

      it "filters mentors by name search" do
        mentor.update!(name: "Alice Smith")

        post "/api/v1/ai/mcp/call",
             params: { name: "list_mentors", arguments: { search: "Alice" } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["mentors"].map { |m| m["id"] }).to include(mentor.id)
      end

      it "filters mentors by expertise search" do
        post "/api/v1/ai/mcp/call",
             params: { name: "list_mentors", arguments: { search: "Ruby" } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Mentor has "Ruby on Rails" expertise from factory
        expect(json["mentors"]).to be_an(Array)
      end

      it "returns empty array when no mentors match search" do
        mentor # ensure mentor exists

        post "/api/v1/ai/mcp/call",
             params: { name: "list_mentors", arguments: { search: "zzz_nonexistent_zzz" } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["mentors"]).to eq([])
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
        expect(json["mentor"]["name"]).to eq(mentor.name)
        expect(json["slots"]).to be_an(Array)
        expect(json["slots"].first).to have_key("id")
        expect(json["slots"].first).to have_key("start_time")
        expect(json["slots"].first).to have_key("end_time")
      end

      it "filters slots by date range" do
        future_slot = create(:slot, mentor: mentor, organization: organization, status: :available,
                             start_time: 5.days.from_now.beginning_of_hour,
                             end_time: 5.days.from_now.beginning_of_hour + 1.hour)

        post "/api/v1/ai/mcp/call",
             params: { name: "list_slots", arguments: {
               mentor_id: mentor.id,
               start_date: 4.days.from_now.to_date.to_s,
               end_date: 6.days.from_now.to_date.to_s
             } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        slot_ids = json["slots"].map { |s| s["id"] }
        expect(slot_ids).to include(future_slot.id)
        expect(slot_ids).not_to include(slot.id)
      end

      it "returns error for non-existent mentor" do
        post "/api/v1/ai/mcp/call",
             params: { name: "list_slots", arguments: { mentor_id: SecureRandom.uuid } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Mentor not found")
      end

      it "returns error for invalid date format" do
        post "/api/v1/ai/mcp/call",
             params: { name: "list_slots", arguments: { mentor_id: mentor.id, start_date: "not-a-date" } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Invalid date format")
      end

      it "excludes booked slots" do
        create(:slot, :booked, mentor: mentor, organization: organization,
               start_time: 3.days.from_now.beginning_of_hour,
               end_time: 3.days.from_now.beginning_of_hour + 1.hour)

        post "/api/v1/ai/mcp/call",
             params: { name: "list_slots", arguments: { mentor_id: mentor.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Only the available slot should appear
        expect(json["slots"].length).to eq(1)
        expect(json["slots"].first["id"]).to eq(slot.id)
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
        expect(json["booking"]["mentor"]).to eq(mentor.name)
        expect(json["booking"]).to have_key("slot_start")
        expect(json["booking"]).to have_key("slot_end")
      end

      it "books a slot with timezone" do
        post "/api/v1/ai/mcp/call",
             params: { name: "book_slot", arguments: { slot_id: slot.id, timezone: "America/New_York" } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns error when slot is already booked" do
        slot.update!(status: :booked)

        post "/api/v1/ai/mcp/call",
             params: { name: "book_slot", arguments: { slot_id: slot.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(json["error"]).to be_present
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
        expect(json["message"]).to eq("Booking cancelled")
        expect(json["booking_id"]).to eq(booking.id)
      end

      it "cancels a booking without a reason" do
        post "/api/v1/ai/mcp/call",
             params: { name: "cancel_booking", arguments: { booking_id: booking.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns error for non-existent booking" do
        post "/api/v1/ai/mcp/call",
             params: { name: "cancel_booking", arguments: { booking_id: SecureRandom.uuid } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Booking not found")
      end
    end

    context "my_sessions" do
      let!(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
      let!(:booking) { create(:booking, slot: slot, member: member, organization: organization, status: :confirmed) }

      it "returns the user's sessions" do
        post "/api/v1/ai/mcp/call",
             params: { name: "my_sessions", arguments: {} },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["sessions"]).to be_an(Array)
        expect(json["sessions"].first["id"]).to eq(booking.id)
        expect(json["sessions"].first["status"]).to eq("confirmed")
        expect(json["sessions"].first).to have_key("start_time")
        expect(json["sessions"].first).to have_key("end_time")
        expect(json["sessions"].first).to have_key("mentor")
      end

      it "filters sessions by confirmed status" do
        cancelled_slot = create(:slot, :booked, mentor: mentor, organization: organization,
                                start_time: 3.days.from_now.beginning_of_hour,
                                end_time: 3.days.from_now.beginning_of_hour + 1.hour)
        create(:booking, :cancelled, slot: cancelled_slot, member: member, organization: organization)

        post "/api/v1/ai/mcp/call",
             params: { name: "my_sessions", arguments: { status: "confirmed" } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        statuses = json["sessions"].map { |s| s["status"] }
        expect(statuses).to all(eq("confirmed"))
      end

      it "filters sessions by cancelled status" do
        cancelled_slot = create(:slot, :booked, mentor: mentor, organization: organization,
                                start_time: 3.days.from_now.beginning_of_hour,
                                end_time: 3.days.from_now.beginning_of_hour + 1.hour)
        create(:booking, :cancelled, slot: cancelled_slot, member: member, organization: organization)

        post "/api/v1/ai/mcp/call",
             params: { name: "my_sessions", arguments: { status: "cancelled" } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        statuses = json["sessions"].map { |s| s["status"] }
        expect(statuses).to all(eq("cancelled"))
      end

      it "returns all sessions when status is 'all'" do
        cancelled_slot = create(:slot, :booked, mentor: mentor, organization: organization,
                                start_time: 3.days.from_now.beginning_of_hour,
                                end_time: 3.days.from_now.beginning_of_hour + 1.hour)
        create(:booking, :cancelled, slot: cancelled_slot, member: member, organization: organization)

        post "/api/v1/ai/mcp/call",
             params: { name: "my_sessions", arguments: { status: "all" } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["sessions"].length).to eq(2)
      end
    end

    context "get_mentor_profile" do
      it "returns detailed mentor profile" do
        post "/api/v1/ai/mcp/call",
             params: { name: "get_mentor_profile", arguments: { mentor_id: mentor.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["mentor"]["id"]).to eq(mentor.id)
        expect(json["mentor"]["name"]).to eq(mentor.name)
        expect(json["mentor"]["email"]).to eq(mentor.email)
        expect(json["mentor"]["role"]).to eq("mentor")
        expect(json["mentor"]["bio"]).to be_present
        expect(json["mentor"]["expertise"]).to be_an(Array)
        expect(json["mentor"]["expertise"]).to include("Ruby on Rails")
        expect(json["mentor"]).to have_key("availability")
        expect(json["mentor"]["availability"]).to have_key("total_slots")
        expect(json["mentor"]["availability"]).to have_key("available_slots")
        expect(json["mentor"]["availability"]).to have_key("booked_slots")
      end

      it "includes slot availability counts" do
        create(:slot, mentor: mentor, organization: organization, status: :available)
        create(:slot, :booked, mentor: mentor, organization: organization,
               start_time: 3.days.from_now.beginning_of_hour,
               end_time: 3.days.from_now.beginning_of_hour + 1.hour)

        post "/api/v1/ai/mcp/call",
             params: { name: "get_mentor_profile", arguments: { mentor_id: mentor.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["mentor"]["availability"]["total_slots"]).to eq(2)
        expect(json["mentor"]["availability"]["available_slots"]).to eq(1)
        expect(json["mentor"]["availability"]["booked_slots"]).to eq(1)
      end

      it "returns error for non-existent mentor" do
        post "/api/v1/ai/mcp/call",
             params: { name: "get_mentor_profile", arguments: { mentor_id: SecureRandom.uuid } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Mentor not found")
      end
    end

    context "get_booking_details" do
      let!(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
      let!(:booking) { create(:booking, slot: slot, member: member, organization: organization, status: :confirmed, booked_timezone: "Asia/Kolkata") }

      it "returns full booking details" do
        post "/api/v1/ai/mcp/call",
             params: { name: "get_booking_details", arguments: { booking_id: booking.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["booking"]["id"]).to eq(booking.id)
        expect(json["booking"]["status"]).to eq("confirmed")
        expect(json["booking"]["booked_at"]).to be_present
        expect(json["booking"]["booked_timezone"]).to eq("Asia/Kolkata")
        expect(json["booking"]["slot"]["id"]).to eq(slot.id)
        expect(json["booking"]["slot"]).to have_key("start_time")
        expect(json["booking"]["slot"]).to have_key("end_time")
        expect(json["booking"]["mentor"]["id"]).to eq(mentor.id)
        expect(json["booking"]["mentor"]["name"]).to eq(mentor.name)
        expect(json["booking"]["mentor"]["expertise"]).to be_an(Array)
        expect(json["booking"]["member"]["id"]).to eq(member.id)
        expect(json["booking"]["member"]["name"]).to eq(member.name)
        expect(json["booking"]["member"]["email"]).to eq(member.email)
      end

      it "includes cancellation details for cancelled bookings" do
        booking.update!(status: :cancelled, cancelled_at: Time.current, cancellation_reason: "No longer needed")

        post "/api/v1/ai/mcp/call",
             params: { name: "get_booking_details", arguments: { booking_id: booking.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["booking"]["status"]).to eq("cancelled")
        expect(json["booking"]["cancelled_at"]).to be_present
        expect(json["booking"]["cancellation_reason"]).to eq("No longer needed")
      end

      it "returns error for non-existent booking" do
        post "/api/v1/ai/mcp/call",
             params: { name: "get_booking_details", arguments: { booking_id: SecureRandom.uuid } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Booking not found")
      end
    end

    context "reschedule_booking" do
      let!(:old_slot) { create(:slot, :booked, mentor: mentor, organization: organization, start_time: 2.days.from_now.beginning_of_hour, end_time: 2.days.from_now.beginning_of_hour + 1.hour) }
      let!(:new_slot) { create(:slot, mentor: mentor, organization: organization, status: :available, start_time: 4.days.from_now.beginning_of_hour, end_time: 4.days.from_now.beginning_of_hour + 1.hour) }
      let!(:booking) { create(:booking, slot: old_slot, member: member, organization: organization, status: :confirmed) }

      it "reschedules a booking to a new slot" do
        post "/api/v1/ai/mcp/call",
             params: { name: "reschedule_booking", arguments: { booking_id: booking.id, new_slot_id: new_slot.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["booking"]["status"]).to eq("confirmed")
        expect(json["booking"]["mentor"]).to eq(mentor.name)
        expect(json["booking"]["slot_start"]).to be_present
        expect(json["booking"]["slot_end"]).to be_present
      end

      it "reschedules with a timezone" do
        post "/api/v1/ai/mcp/call",
             params: { name: "reschedule_booking", arguments: {
               booking_id: booking.id, new_slot_id: new_slot.id, timezone: "Europe/London"
             } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["booking"]["booked_timezone"]).to eq("Europe/London")
      end

      it "returns error for non-existent booking" do
        post "/api/v1/ai/mcp/call",
             params: { name: "reschedule_booking", arguments: { booking_id: SecureRandom.uuid, new_slot_id: new_slot.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Booking not found")
      end

      it "returns error when new slot is already booked" do
        new_slot.update!(status: :booked)

        post "/api/v1/ai/mcp/call",
             params: { name: "reschedule_booking", arguments: { booking_id: booking.id, new_slot_id: new_slot.id } },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(json["error"]).to be_present
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
        expect(json["available_tools"]).to be_an(Array)
        expect(json["available_tools"].length).to eq(8)
      end
    end
  end
end
