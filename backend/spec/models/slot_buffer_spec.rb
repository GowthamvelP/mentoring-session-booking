require "rails_helper"

RSpec.describe "Slot buffer validation", type: :model do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  let!(:existing_slot) do
    create(:slot, mentor: mentor, organization: organization,
           start_time: 2.days.from_now.change(hour: 10),
           end_time: 2.days.from_now.change(hour: 11),
           buffer_minutes: 15)
  end

  it "rejects a slot that starts within buffer of existing slot's end" do
    # Existing: 10:00-11:00 with 15min buffer
    # New: 11:10-12:10 — within 15min buffer of existing end
    slot = build(:slot, mentor: mentor, organization: organization,
                 start_time: 2.days.from_now.change(hour: 11, min: 10),
                 end_time: 2.days.from_now.change(hour: 12, min: 10))
    expect(slot).not_to be_valid
    expect(slot.errors[:start_time].first).to include("buffer")
  end

  it "allows a slot that starts after buffer period" do
    # Existing: 10:00-11:00 with 15min buffer
    # New: 11:20-12:20 — after buffer
    slot = build(:slot, mentor: mentor, organization: organization,
                 start_time: 2.days.from_now.change(hour: 11, min: 20),
                 end_time: 2.days.from_now.change(hour: 12, min: 20))
    expect(slot).to be_valid
  end

  it "rejects a slot that ends within buffer of existing slot's start" do
    # Existing: 10:00-11:00
    # New: 9:00-9:50 — end time within 15min of existing start
    slot = build(:slot, mentor: mentor, organization: organization,
                 start_time: 2.days.from_now.change(hour: 9),
                 end_time: 2.days.from_now.change(hour: 9, min: 50))
    expect(slot).not_to be_valid
  end

  it "allows slots for different mentors at the same time" do
    other_mentor = create(:user, :mentor, organization: organization)
    slot = build(:slot, mentor: other_mentor, organization: organization,
                 start_time: 2.days.from_now.change(hour: 10),
                 end_time: 2.days.from_now.change(hour: 11))
    expect(slot).to be_valid
  end
end
