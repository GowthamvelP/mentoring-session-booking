require "rails_helper"

RSpec.describe "Concurrency: Double-booking prevention", type: :service do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:slot) { create(:slot, mentor: mentor, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  # Property 2: Pessimistic lock prevents double-booking
  # Feature: mentoring-session-booking, Property 2: Pessimistic lock prevents double-booking
  # **Validates: Requirements 5.1, 5.8**
  it "property: only one of N concurrent bookings succeeds" do
    members = create_list(:user, 5, :member, organization: organization)
    results = []
    mutex = Mutex.new
    threads = []

    members.each do |m|
      threads << Thread.new do
        # Each thread gets its own connection from the pool
        ActiveRecord::Base.connection_pool.with_connection do
          ActsAsTenant.with_tenant(organization) do
            result = BookingService.call(
              slot_id: slot.id,
              member: m,
              idempotency_key: SecureRandom.uuid
            )
            mutex.synchronize { results << result }
          end
        end
      end
    end

    threads.each(&:join)

    successes = results.select { |r| r[:success] && !r[:existing] }
    failures = results.reject { |r| r[:success] }

    expect(successes.count).to eq(1), "Expected exactly 1 success, got #{successes.count}"
    expect(failures.count).to eq(4), "Expected 4 failures, got #{failures.count}"
    expect(Booking.where(slot_id: slot.id).count).to eq(1)
    expect(slot.reload.status).to eq("booked")
  end

  # Property 8: Booking transaction atomicity
  # Feature: mentoring-session-booking, Property 8: Booking transaction atomicity
  # **Validates: Requirements 5.7**
  it "property: if booking creation fails, slot remains available" do
    # Create a slot and attempt to book with invalid data that would cause failure
    test_slot = create(:slot, mentor: mentor, organization: organization,
                       start_time: 5.days.from_now.beginning_of_hour,
                       end_time: 5.days.from_now.beginning_of_hour + 1.hour)

    # Simulate a failure during booking creation by stubbing Booking.create! to raise
    allow(Booking).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Booking.new))

    result = BookingService.call(
      slot_id: test_slot.id,
      member: member,
      idempotency_key: SecureRandom.uuid
    )

    # The slot should remain available since the transaction was rolled back
    expect(result[:success]).to be false
    expect(test_slot.reload.status).to eq("available")
  end

  private

  def member
    @member ||= create(:user, :member, organization: organization)
  end
end
