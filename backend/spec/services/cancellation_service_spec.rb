require "rails_helper"

RSpec.describe CancellationService, type: :service do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
  let(:booking) { create(:booking, slot: slot, member: member, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe ".call" do
    context "successful cancellation" do
      it "cancels the booking and releases the slot" do
        result = described_class.call(booking: booking, user: member)

        expect(result[:success]).to be true
        expect(booking.reload.status).to eq("cancelled")
        expect(booking.cancelled_at).to be_present
        expect(slot.reload.status).to eq("available")
      end

      it "enqueues BookingCancellationJob" do
        expect {
          described_class.call(booking: booking, user: member)
        }.to have_enqueued_job(BookingCancellationJob)
      end

      # Property 3: Cancellation restores slot availability
      # Feature: mentoring-session-booking, Property 3: Cancellation restores slot availability
      # **Validates: Requirements 7.1, 7.2, 7.3**
      it "property: after cancellation, slot is available and booking is cancelled" do
        result = described_class.call(booking: booking, user: member)

        expect(result[:success]).to be true
        expect(slot.reload).to be_available
        expect(booking.reload).to be_cancelled
      end
    end

    context "ownership" do
      let(:other_member) { create(:user, :member, organization: organization) }

      it "rejects cancellation by non-owner" do
        result = described_class.call(booking: booking, user: other_member)

        expect(result[:success]).to be false
        expect(result[:status]).to eq(:forbidden)
        expect(booking.reload.status).to eq("confirmed")
      end
    end

    context "cancellation window" do
      let(:soon_slot) { create(:slot, :booked, :soon, mentor: mentor, organization: organization) }
      let(:soon_booking) { create(:booking, slot: soon_slot, member: member, organization: organization) }

      # Property 6: Cancellation window enforcement
      # Feature: mentoring-session-booking, Property 6: Cancellation window enforcement
      # **Validates: Requirements 7.6**
      it "property: rejects cancellation within 1 hour of slot start" do
        result = described_class.call(booking: soon_booking, user: member)

        expect(result[:success]).to be false
        expect(result[:error]).to include("1 hour")
        expect(soon_booking.reload.status).to eq("confirmed")
        expect(soon_slot.reload.status).to eq("booked")
      end
    end

    context "already cancelled" do
      let(:cancelled_booking) { create(:booking, :cancelled, slot: slot, member: member, organization: organization) }

      it "rejects cancellation of non-confirmed booking" do
        result = described_class.call(booking: cancelled_booking, user: member)

        expect(result[:success]).to be false
        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end
  end
end
