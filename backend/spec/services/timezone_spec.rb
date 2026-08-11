require "rails_helper"

RSpec.describe "Timezone handling", type: :service do
  let(:organization) { create(:organization, timezone: "America/New_York") }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe "slot time storage" do
    it "stores slot times in UTC regardless of org timezone" do
      # Create a slot at 2pm Eastern (which is 6pm/18:00 UTC)
      eastern_time = 3.days.from_now.in_time_zone("America/New_York").change(hour: 14)
      slot = create(:slot, mentor: mentor, organization: organization,
                    start_time: eastern_time,
                    end_time: eastern_time + 1.hour)

      # Reload to get DB-stored value
      slot.reload

      # Verify stored in UTC
      expect(slot.start_time.zone).to eq("UTC")
      # The hour should be offset from Eastern (UTC-4 in summer, UTC-5 in winter)
      expect(slot.start_time.hour).not_to eq(14) # Not stored as 14 (Eastern)
    end

    it "organization timezone is a valid IANA zone" do
      expect(organization.timezone).to eq("America/New_York")
      expect { Time.find_zone!(organization.timezone) }.not_to raise_error
    end
  end

  describe "API response format" do
    it "returns slot times in ISO 8601 UTC format" do
      slot = create(:slot, mentor: mentor, organization: organization)
      serialized = SlotBlueprint.render_as_hash(slot)

      expect(serialized[:start_time]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      expect(serialized[:start_time]).to end_with("Z") # UTC indicator
    end
  end

  describe "cross-timezone consistency" do
    it "same absolute time renders identically regardless of server timezone" do
      slot = create(:slot, mentor: mentor, organization: organization,
                    start_time: Time.utc(2026, 8, 15, 18, 0, 0),
                    end_time: Time.utc(2026, 8, 15, 19, 0, 0))

      serialized = SlotBlueprint.render_as_hash(slot)
      expect(serialized[:start_time]).to eq("2026-08-15T18:00:00Z")
      expect(serialized[:end_time]).to eq("2026-08-15T19:00:00Z")
    end
  end
end
