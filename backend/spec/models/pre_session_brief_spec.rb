# frozen_string_literal: true

require "rails_helper"

RSpec.describe PreSessionBrief, type: :model do
  let(:organization) { create(:organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
  let(:booking) { create(:booking, slot: slot, member: member, organization: organization, status: :confirmed) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  it "belongs to a booking" do
    brief = PreSessionBrief.create!(booking: booking, content: "Test", model_used: "stub", status: "generated")
    expect(brief.booking).to eq(booking)
  end

  it "validates content presence when generated" do
    brief = PreSessionBrief.new(booking: booking, status: "generated", content: nil)
    expect(brief).not_to be_valid
  end

  it "allows blank content when pending" do
    brief = PreSessionBrief.new(booking: booking, status: "pending", content: nil)
    expect(brief).to be_valid
  end

  describe "scopes" do
    it ".generated returns only generated briefs" do
      PreSessionBrief.create!(booking: booking, content: "Brief", model_used: "stub", status: "generated")
      expect(PreSessionBrief.where(booking: booking).generated.count).to eq(1)
      expect(PreSessionBrief.where(booking: booking).pending.count).to eq(0)
    end
  end
end
