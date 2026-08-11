require "rails_helper"

RSpec.describe "Bookings API", type: :request do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:slot) { create(:slot, mentor: mentor, organization: organization) }

  let(:headers) do
    { "X-User-Id" => member.id, "X-Org-Id" => organization.id }
  end

  describe "POST /api/v1/bookings" do
    it "creates a booking successfully" do
      post "/api/v1/bookings",
           params: { slot_id: slot.id, idempotency_key: SecureRandom.uuid },
           headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["status"]).to eq("confirmed")
    end

    it "returns 200 for duplicate idempotency_key" do
      key = SecureRandom.uuid
      post "/api/v1/bookings", params: { slot_id: slot.id, idempotency_key: key }, headers: headers
      expect(response).to have_http_status(:created)

      post "/api/v1/bookings", params: { slot_id: slot.id, idempotency_key: key }, headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "returns 422 without idempotency_key" do
      post "/api/v1/bookings", params: { slot_id: slot.id }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 409 for already-booked slot" do
      slot.update!(status: :booked)
      post "/api/v1/bookings",
           params: { slot_id: slot.id, idempotency_key: SecureRandom.uuid },
           headers: headers

      expect(response).to have_http_status(:conflict)
    end

    it "returns 401 without auth headers" do
      post "/api/v1/bookings", params: { slot_id: slot.id, idempotency_key: SecureRandom.uuid }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns error JSON with expected structure" do
      post "/api/v1/bookings", params: { slot_id: slot.id }, headers: headers
      json = JSON.parse(response.body)

      expect(json).to have_key("error")
    end
  end

  describe "PATCH /api/v1/bookings/:id/cancel" do
    let(:booked_slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
    let(:booking) { create(:booking, slot: booked_slot, member: member, organization: organization) }

    it "cancels a booking successfully" do
      patch "/api/v1/bookings/#{booking.id}/cancel", headers: headers

      expect(response).to have_http_status(:ok)
      expect(booking.reload.status).to eq("cancelled")
      expect(booked_slot.reload.status).to eq("available")
    end

    it "returns 422 for booking within cancellation window" do
      soon_slot = create(:slot, :booked, :soon, mentor: mentor, organization: organization)
      soon_booking = create(:booking, slot: soon_slot, member: member, organization: organization)

      patch "/api/v1/bookings/#{soon_booking.id}/cancel", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 403 when non-owner attempts cancellation" do
      other_member = create(:user, :member, organization: organization)
      other_headers = { "X-User-Id" => other_member.id, "X-Org-Id" => organization.id }

      patch "/api/v1/bookings/#{booking.id}/cancel", headers: other_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without auth headers" do
      patch "/api/v1/bookings/#{booking.id}/cancel"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/bookings/:id/reschedule" do
    let(:booked_slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
    let(:booking) { create(:booking, slot: booked_slot, member: member, organization: organization) }
    let(:target_slot) { create(:slot, mentor: mentor, organization: organization, start_time: 5.days.from_now.beginning_of_hour, end_time: 5.days.from_now.beginning_of_hour + 1.hour) }

    it "reschedules successfully" do
      post "/api/v1/bookings/#{booking.id}/reschedule",
           params: { new_slot_id: target_slot.id },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(booking.reload.status).to eq("cancelled")
      expect(target_slot.reload.status).to eq("booked")
    end

    it "returns error when new slot is already booked" do
      booked_target = create(:slot, :booked, mentor: mentor, organization: organization,
                             start_time: 6.days.from_now.beginning_of_hour,
                             end_time: 6.days.from_now.beginning_of_hour + 1.hour)

      post "/api/v1/bookings/#{booking.id}/reschedule",
           params: { new_slot_id: booked_target.id },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(booking.reload.status).to eq("confirmed")
    end

    it "returns 401 without auth headers" do
      post "/api/v1/bookings/#{booking.id}/reschedule", params: { new_slot_id: target_slot.id }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
