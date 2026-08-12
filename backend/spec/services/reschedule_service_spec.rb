require "rails_helper"

RSpec.describe RescheduleService, type: :service do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:original_slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
  let(:new_slot) { create(:slot, mentor: mentor, organization: organization, start_time: 3.days.from_now.beginning_of_hour, end_time: 3.days.from_now.beginning_of_hour + 1.hour) }
  let(:booking) { create(:booking, slot: original_slot, member: member, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe ".call" do
    context "successful reschedule" do
      it "cancels old booking and creates new one atomically" do
        result = described_class.call(booking: booking, new_slot_id: new_slot.id, user: member)

        expect(result[:success]).to be true
        expect(result[:booking]).to be_persisted
        expect(result[:booking].status).to eq("confirmed")
        expect(result[:booking].slot).to eq(new_slot)
        expect(result[:old_booking].status).to eq("cancelled")
        expect(original_slot.reload.status).to eq("available")
        expect(new_slot.reload.status).to eq("booked")
      end

      it "creates notifications for member and mentor" do
        expect {
          described_class.call(booking: booking, new_slot_id: new_slot.id, user: member)
        }.to change(Notification, :count).by(2)
      end

      # Property 9: Reschedule preserves booking count
      # Feature: mentoring-session-booking, Property 9: Reschedule preserves booking count
      # **Validates: Requirements 8.1**
      it "property: member's confirmed booking count remains the same" do
        # Ensure booking is created first so count includes it
        booking
        initial_count = member.bookings.confirmed.count

        described_class.call(booking: booking, new_slot_id: new_slot.id, user: member)

        expect(member.bookings.confirmed.count).to eq(initial_count)
      end
    end

    context "new slot unavailable" do
      let(:booked_new_slot) { create(:slot, :booked, mentor: mentor, organization: organization, start_time: 4.days.from_now.beginning_of_hour, end_time: 4.days.from_now.beginning_of_hour + 1.hour) }

      # Property 4: Reschedule atomicity
      # Feature: mentoring-session-booking, Property 4: Reschedule atomicity
      # **Validates: Requirements 8.2, 8.4**
      it "property: if new slot unavailable, original booking preserved" do
        result = described_class.call(booking: booking, new_slot_id: booked_new_slot.id, user: member)

        expect(result[:success]).to be false
        expect(booking.reload.status).to eq("confirmed")
        expect(original_slot.reload.status).to eq("booked")
      end
    end

    context "same slot" do
      it "rejects reschedule to same slot" do
        result = described_class.call(booking: booking, new_slot_id: original_slot.id, user: member)

        expect(result[:success]).to be false
        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:error]).to include("different")
      end
    end

    context "ownership" do
      let(:other_member) { create(:user, :member, organization: organization) }

      it "rejects reschedule by non-owner" do
        result = described_class.call(booking: booking, new_slot_id: new_slot.id, user: other_member)

        expect(result[:success]).to be false
        expect(result[:status]).to eq(:forbidden)
      end
    end

    context "non-confirmed booking" do
      let(:cancelled_booking) { create(:booking, :cancelled, slot: original_slot, member: member, organization: organization) }

      it "rejects reschedule of non-confirmed booking" do
        result = described_class.call(booking: cancelled_booking, new_slot_id: new_slot.id, user: member)

        expect(result[:success]).to be false
        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end

    context "new slot not found" do
      it "returns not_found for invalid slot ID" do
        result = described_class.call(booking: booking, new_slot_id: SecureRandom.uuid, user: member)

        expect(result[:success]).to be false
        expect(result[:status]).to eq(:not_found)
      end
    end

    context "unexpected validation error during transaction" do
      it "returns failure with error message when RecordInvalid is raised" do
        allow(Booking).to receive(:create!).and_raise(
          ActiveRecord::RecordInvalid.new(Booking.new)
        )

        result = described_class.call(booking: booking, new_slot_id: new_slot.id, user: member)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Reschedule failed")
        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end

    context "timezone handling" do
      it "stores provided timezone on new booking" do
        result = described_class.call(
          booking: booking, new_slot_id: new_slot.id, user: member,
          timezone: "Asia/Kolkata"
        )

        expect(result[:success]).to be true
        expect(result[:booking].booked_timezone).to eq("Asia/Kolkata")
      end

      it "inherits original booking timezone when none provided" do
        booking.update!(booked_timezone: "America/New_York")
        result = described_class.call(booking: booking, new_slot_id: new_slot.id, user: member)

        expect(result[:success]).to be true
        expect(result[:booking].booked_timezone).to eq("America/New_York")
      end
    end
  end
end
