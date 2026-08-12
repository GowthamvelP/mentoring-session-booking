# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingBriefJob, type: :job do
  let(:organization) { create(:organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
  let(:booking) { create(:booking, slot: slot, member: member, organization: organization, status: :confirmed) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  it "generates a stub brief for a confirmed booking" do
    expect { described_class.new.perform(booking.id) }.to change(PreSessionBrief, :count).by(1)
    brief = PreSessionBrief.last
    expect(brief.status).to eq("generated")
    expect(brief.model_used).to eq("stub")
    expect(brief.content).to include("Pre-Session Brief")
  end

  it "is idempotent — skips if brief already exists" do
    PreSessionBrief.create!(booking: booking, content: "Existing", model_used: "stub", status: "generated")
    expect { described_class.new.perform(booking.id) }.not_to change(PreSessionBrief, :count)
  end

  it "skips cancelled bookings" do
    booking.update!(status: :cancelled)
    expect { described_class.new.perform(booking.id) }.not_to change(PreSessionBrief, :count)
  end

  it "skips non-existent bookings" do
    expect { described_class.new.perform("non-existent-id") }.not_to change(PreSessionBrief, :count)
  end
end
