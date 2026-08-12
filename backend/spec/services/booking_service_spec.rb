require "rails_helper"

RSpec.describe BookingService, type: :service do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:slot) { create(:slot, mentor: mentor, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe ".call" do
    context "successful booking" do
      it "creates a booking and marks slot as booked" do
        result = described_class.call(
          slot_id: slot.id,
          member: member,
          idempotency_key: SecureRandom.uuid
        )

        expect(result[:success]).to be true
        expect(result[:booking]).to be_persisted
        expect(result[:booking].status).to eq("confirmed")
        expect(result[:booking].member).to eq(member)
        expect(slot.reload.status).to eq("booked")
      end

      it "enqueues BookingConfirmationJob" do
        expect {
          described_class.call(slot_id: slot.id, member: member, idempotency_key: SecureRandom.uuid)
        }.to have_enqueued_job(BookingConfirmationJob)
      end
    end

    context "idempotency" do
      let(:key) { SecureRandom.uuid }

      it "returns existing booking for duplicate idempotency_key" do
        result1 = described_class.call(slot_id: slot.id, member: member, idempotency_key: key)
        result2 = described_class.call(slot_id: slot.id, member: member, idempotency_key: key)

        expect(result1[:success]).to be true
        expect(result2[:success]).to be true
        expect(result2[:existing]).to be true
        expect(result1[:booking].id).to eq(result2[:booking].id)
        expect(Booking.where(idempotency_key: key).count).to eq(1)
      end

      # Property 1: Idempotency round-trip
      # Feature: mentoring-session-booking, Property 1: Idempotency round-trip
      # **Validates: Requirements 6.5, 6.2**
      it "property: submitting same key N times creates exactly 1 booking" do
        key = SecureRandom.uuid
        results = 5.times.map do
          described_class.call(slot_id: slot.id, member: member, idempotency_key: key)
        end

        expect(results.map { |r| r[:success] }).to all(be true)
        expect(results.map { |r| r[:booking].id }.uniq.size).to eq(1)
        expect(Booking.where(idempotency_key: key).count).to eq(1)
      end
    end

    context "slot unavailable" do
      let(:booked_slot) { create(:slot, :booked, mentor: mentor, organization: organization) }

      it "returns conflict when slot is already booked" do
        result = described_class.call(
          slot_id: booked_slot.id,
          member: member,
          idempotency_key: SecureRandom.uuid
        )

        expect(result[:success]).to be false
        expect(result[:status]).to eq(:conflict)
      end
    end

    context "slot not found" do
      it "returns not_found for invalid slot_id" do
        result = described_class.call(
          slot_id: SecureRandom.uuid,
          member: member,
          idempotency_key: SecureRandom.uuid
        )

        expect(result[:success]).to be false
        expect(result[:status]).to eq(:not_found)
      end
    end

    context "timezone storage" do
      it "stores provided timezone on booking" do
        result = described_class.call(
          slot_id: slot.id, member: member,
          idempotency_key: SecureRandom.uuid,
          timezone: "Europe/London"
        )

        expect(result[:success]).to be true
        expect(result[:booking].booked_timezone).to eq("Europe/London")
      end

      it "defaults to org timezone when none provided" do
        result = described_class.call(
          slot_id: slot.id, member: member,
          idempotency_key: SecureRandom.uuid
        )

        expect(result[:success]).to be true
        expect(result[:booking].booked_timezone).to eq(organization.timezone)
      end
    end

    context "unexpected validation error during transaction" do
      it "returns failure when RecordInvalid is not an idempotency collision" do
        allow(Booking).to receive(:create!).and_raise(
          ActiveRecord::RecordInvalid.new(Booking.new)
        )

        result = described_class.call(
          slot_id: slot.id,
          member: member,
          idempotency_key: SecureRandom.uuid
        )

        expect(result[:success]).to be false
        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end

    context "buffer validation" do
      it "rejects booking when buffer is violated" do
        # Create a booked slot for the same mentor
        booked_slot = create(:slot, mentor: mentor, organization: organization,
                             start_time: 2.days.from_now.beginning_of_hour,
                             end_time: 2.days.from_now.beginning_of_hour + 1.hour,
                             status: :available, buffer_minutes: 15)
        # Mark it as booked after creation to avoid create-time validation
        booked_slot.update_column(:status, "booked")

        # This slot starts only 5 min after the booked one ends (violates 15 min buffer)
        # Use build + save(validate: false) to bypass create-time overlap validation
        target_slot = Slot.new(
          mentor: mentor,
          organization: organization,
          start_time: booked_slot.end_time + 5.minutes,
          end_time: booked_slot.end_time + 65.minutes,
          status: :available,
          buffer_minutes: 15
        )
        target_slot.save!(validate: false)

        result = described_class.call(
          slot_id: target_slot.id,
          member: member,
          idempotency_key: SecureRandom.uuid
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include("Buffer")
        expect(result[:status]).to eq(:conflict)
      end

      it "allows booking when buffer is respected" do
        # Create a booked slot for the same mentor
        booked_slot = create(:slot, mentor: mentor, organization: organization,
                             start_time: 3.days.from_now.beginning_of_hour,
                             end_time: 3.days.from_now.beginning_of_hour + 1.hour,
                             status: :available, buffer_minutes: 15)
        booked_slot.update_column(:status, "booked")

        # This slot starts 30 min after (respects 15 min buffer)
        target_slot = create(:slot, mentor: mentor, organization: organization,
                             start_time: booked_slot.end_time + 30.minutes,
                             end_time: booked_slot.end_time + 90.minutes,
                             status: :available, buffer_minutes: 15)

        result = described_class.call(
          slot_id: target_slot.id,
          member: member,
          idempotency_key: SecureRandom.uuid
        )

        expect(result[:success]).to be true
        expect(result[:booking]).to be_persisted
      end
    end
  end
end
