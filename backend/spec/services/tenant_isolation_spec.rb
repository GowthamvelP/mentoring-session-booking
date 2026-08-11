require "rails_helper"

RSpec.describe "Tenant Isolation", type: :service do
  let(:org_a) { create(:organization, name: "Org A") }
  let(:org_b) { create(:organization, name: "Org B") }

  # Property 5: Tenant isolation
  # Feature: mentoring-session-booking, Property 5: Tenant isolation
  # **Validates: Requirements 1.2, 1.5**
  it "property: org A cannot see org B's data" do
    # Create data in org A
    mentor_a = nil
    ActsAsTenant.with_tenant(org_a) do
      mentor_a = create(:user, :mentor, organization: org_a)
      3.times do |i|
        create(:slot, mentor: mentor_a, organization: org_a,
               start_time: (i + 1).days.from_now.beginning_of_hour,
               end_time: (i + 1).days.from_now.beginning_of_hour + 1.hour)
      end
    end

    # Create data in org B
    ActsAsTenant.with_tenant(org_b) do
      mentor_b = create(:user, :mentor, organization: org_b)
      3.times do |i|
        create(:slot, mentor: mentor_b, organization: org_b,
               start_time: (i + 1).days.from_now.beginning_of_hour,
               end_time: (i + 1).days.from_now.beginning_of_hour + 1.hour)
      end
    end

    # Query in org A context — should only see org A data
    ActsAsTenant.with_tenant(org_a) do
      expect(User.mentors.count).to eq(1)
      expect(Slot.count).to eq(3)
      expect(User.mentors.first).to eq(mentor_a)
    end

    # Query in org B context — should only see org B data
    ActsAsTenant.with_tenant(org_b) do
      expect(User.mentors.count).to eq(1)
      expect(Slot.count).to eq(3)
      expect(User.mentors.first).not_to eq(mentor_a)
    end
  end

  it "booking in org A is invisible in org B" do
    ActsAsTenant.with_tenant(org_a) do
      mentor = create(:user, :mentor, organization: org_a)
      member = create(:user, :member, organization: org_a)
      slot = create(:slot, :booked, mentor: mentor, organization: org_a)
      create(:booking, slot: slot, member: member, organization: org_a)
    end

    ActsAsTenant.with_tenant(org_b) do
      expect(Booking.count).to eq(0)
      expect(Slot.count).to eq(0)
    end
  end

  it "member in org A cannot book a slot that belongs to org B" do
    member_a = nil
    ActsAsTenant.with_tenant(org_a) do
      member_a = create(:user, :member, organization: org_a)
    end

    slot_b = nil
    ActsAsTenant.with_tenant(org_b) do
      mentor_b = create(:user, :mentor, organization: org_b)
      slot_b = create(:slot, mentor: mentor_b, organization: org_b)
    end

    # Attempt to book org B's slot while in org A context
    ActsAsTenant.with_tenant(org_a) do
      result = BookingService.call(
        slot_id: slot_b.id,
        member: member_a,
        idempotency_key: SecureRandom.uuid
      )

      # Should fail because the slot isn't visible in org A's tenant scope
      expect(result[:success]).to be false
    end
  end
end
