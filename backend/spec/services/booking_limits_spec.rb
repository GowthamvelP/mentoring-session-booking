require "rails_helper"

RSpec.describe "Per-member booking limits", type: :service do
  let(:organization) { create(:organization, max_active_bookings: 2) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  it "allows booking up to the limit" do
    2.times do |i|
      slot = create(:slot, mentor: mentor, organization: organization,
                    start_time: (i + 1).days.from_now.beginning_of_hour,
                    end_time: (i + 1).days.from_now.beginning_of_hour + 1.hour)
      result = BookingService.call(slot_id: slot.id, member: member, idempotency_key: SecureRandom.uuid)
      expect(result[:success]).to be true
    end
  end

  it "rejects booking when limit is reached" do
    # Create 2 existing bookings (at limit)
    2.times do |i|
      slot = create(:slot, :booked, mentor: mentor, organization: organization,
                    start_time: (i + 2).days.from_now.beginning_of_hour,
                    end_time: (i + 2).days.from_now.beginning_of_hour + 1.hour)
      create(:booking, slot: slot, member: member, organization: organization)
    end

    # Third attempt should be rejected
    new_slot = create(:slot, mentor: mentor, organization: organization,
                      start_time: 5.days.from_now.beginning_of_hour,
                      end_time: 5.days.from_now.beginning_of_hour + 1.hour)
    result = BookingService.call(slot_id: new_slot.id, member: member, idempotency_key: SecureRandom.uuid)

    expect(result[:success]).to be false
    expect(result[:error]).to include("Booking limit reached")
    expect(result[:status]).to eq(:unprocessable_entity)
  end

  it "allows booking when limit is nil (unlimited)" do
    org = create(:organization, max_active_bookings: nil)
    ActsAsTenant.current_tenant = org
    m = create(:user, :mentor, organization: org)
    member_user = create(:user, :member, organization: org)

    10.times do |i|
      slot = create(:slot, :booked, mentor: m, organization: org,
                    start_time: (i + 1).days.from_now.beginning_of_hour,
                    end_time: (i + 1).days.from_now.beginning_of_hour + 1.hour)
      create(:booking, slot: slot, member: member_user, organization: org)
    end

    new_slot = create(:slot, mentor: m, organization: org,
                      start_time: 15.days.from_now.beginning_of_hour,
                      end_time: 15.days.from_now.beginning_of_hour + 1.hour)
    result = BookingService.call(slot_id: new_slot.id, member: member_user, idempotency_key: SecureRandom.uuid)
    expect(result[:success]).to be true
  end
end
