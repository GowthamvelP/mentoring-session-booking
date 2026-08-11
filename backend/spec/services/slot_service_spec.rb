require "rails_helper"

RSpec.describe SlotService, type: :service do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }

  before do
    ActsAsTenant.current_tenant = organization
    # Use memory store for cache tests (test env uses null_store by default)
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end
  after { ActsAsTenant.current_tenant = nil }

  describe ".available_for_mentor" do
    let!(:available_slot) { create(:slot, mentor: mentor, organization: organization, start_time: 2.days.from_now.beginning_of_hour, end_time: 2.days.from_now.beginning_of_hour + 1.hour) }
    let!(:booked_slot) { create(:slot, :booked, mentor: mentor, organization: organization, start_time: 3.days.from_now.beginning_of_hour, end_time: 3.days.from_now.beginning_of_hour + 1.hour) }

    it "returns only available future slots" do
      result = described_class.available_for_mentor(
        mentor_id: mentor.id,
        start_date: Date.current,
        end_date: Date.current + 7.days
      )

      expect(result).to include(available_slot)
      expect(result).not_to include(booked_slot)
    end

    it "caches results on subsequent calls" do
      # First call populates cache
      result1 = described_class.available_for_mentor(
        mentor_id: mentor.id,
        start_date: Date.current,
        end_date: Date.current + 7.days
      )

      # Second call should return the same result from cache
      result2 = described_class.available_for_mentor(
        mentor_id: mentor.id,
        start_date: Date.current,
        end_date: Date.current + 7.days
      )

      expect(result1).to eq(result2)
    end

    it "does not return past slots" do
      past_slot = create(:slot, :past, mentor: mentor, organization: organization)

      result = described_class.available_for_mentor(
        mentor_id: mentor.id,
        start_date: Date.current - 7.days,
        end_date: Date.current + 7.days
      )

      expect(result).not_to include(past_slot)
    end
  end

  describe ".invalidate_for_mentor" do
    it "clears cached slots for the mentor" do
      # Populate cache
      described_class.available_for_mentor(
        mentor_id: mentor.id,
        start_date: Date.current,
        end_date: Date.current + 7.days
      )

      # Invalidate
      described_class.invalidate_for_mentor(mentor.id)

      # Verify cache key was deleted by checking cache directly
      cache_key = "slots:#{mentor.id}:#{Date.current}:#{Date.current + 7.days}"
      expect(Rails.cache.read(cache_key)).to be_nil
    end
  end

  # Property 7: Cache consistency after mutation
  # Feature: mentoring-session-booking, Property 7: Cache consistency after mutation
  # **Validates: Requirements 5.6, 7.5, 8.6**
  describe "cache consistency after booking" do
    let!(:slot) { create(:slot, mentor: mentor, organization: organization, start_time: 2.days.from_now.beginning_of_hour, end_time: 2.days.from_now.beginning_of_hour + 1.hour) }
    let(:member) { create(:user, :member, organization: organization) }

    it "property: after booking, cached slot listing no longer contains booked slot" do
      # Prime the cache
      slots_before = described_class.available_for_mentor(
        mentor_id: mentor.id,
        start_date: Date.current,
        end_date: Date.current + 7.days
      )
      expect(slots_before).to include(slot)

      # Book the slot (which invalidates cache via BookingService)
      BookingService.call(slot_id: slot.id, member: member, idempotency_key: SecureRandom.uuid)

      # Query again — should not contain the booked slot
      slots_after = described_class.available_for_mentor(
        mentor_id: mentor.id,
        start_date: Date.current,
        end_date: Date.current + 7.days
      )
      expect(slots_after).not_to include(slot)
    end

    it "property: after cancellation, cached slot listing contains restored slot" do
      # Book the slot first
      booking_result = BookingService.call(slot_id: slot.id, member: member, idempotency_key: SecureRandom.uuid)
      booking = booking_result[:booking]

      # Prime cache with booked state
      slots_during = described_class.available_for_mentor(
        mentor_id: mentor.id,
        start_date: Date.current,
        end_date: Date.current + 7.days
      )
      expect(slots_during).not_to include(slot)

      # Cancel (which invalidates cache via CancellationService)
      CancellationService.call(booking: booking, user: member)

      # Query again — slot should be back
      slots_after = described_class.available_for_mentor(
        mentor_id: mentor.id,
        start_date: Date.current,
        end_date: Date.current + 7.days
      )
      expect(slots_after).to include(slot)
    end
  end
end
