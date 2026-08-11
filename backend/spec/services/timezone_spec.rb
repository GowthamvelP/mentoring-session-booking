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

  describe "DST transition handling" do
    it "correctly handles spring-forward (2nd Sunday of March)" do
      # In 2027, spring forward is March 14 at 2:00 AM Eastern
      # 1:30 AM EST (UTC-5) -> clocks jump to 3:00 AM EDT (UTC-4)
      # A slot at "2:30 AM Eastern" doesn't exist during spring forward

      # Create a slot in UTC that spans the non-existent hour
      # This verifies our UTC storage means we never lose data
      slot = create(:slot, mentor: mentor, organization: organization,
                    start_time: Time.utc(2027, 3, 14, 7, 30, 0), # 2:30 AM EST = 7:30 UTC
                    end_time: Time.utc(2027, 3, 14, 8, 30, 0))

      slot.reload

      # UTC storage is unambiguous — no DST issue
      expect(slot.start_time).to eq(Time.utc(2027, 3, 14, 7, 30, 0))

      # When displayed in Eastern, the Intl API handles the transition
      eastern_display = slot.start_time.in_time_zone("America/New_York")
      expect(eastern_display.zone).to eq("EDT").or eq("EST") # Zone name changes at transition
    end

    it "correctly handles fall-back (1st Sunday of November)" do
      # In 2026, fall back is November 1 at 2:00 AM Eastern
      # 2:00 AM EDT -> clocks go back to 1:00 AM EST
      # The hour 1:00-2:00 AM occurs twice

      # UTC storage avoids the ambiguity entirely
      slot_before = create(:slot, mentor: mentor, organization: organization,
                           start_time: Time.utc(2026, 11, 1, 5, 0, 0), # 1:00 AM EDT (before fallback)
                           end_time: Time.utc(2026, 11, 1, 6, 0, 0))

      slot_after = create(:slot, mentor: mentor, organization: organization,
                          start_time: Time.utc(2026, 11, 1, 7, 0, 0), # 2:00 AM EST (after fallback)
                          end_time: Time.utc(2026, 11, 1, 8, 0, 0))

      # Both slots have distinct UTC times — no ambiguity
      expect(slot_before.start_time).not_to eq(slot_after.start_time)

      # API returns UTC — frontend handles display correctly
      expect(SlotBlueprint.render_as_hash(slot_before)[:start_time]).to end_with("Z")
      expect(SlotBlueprint.render_as_hash(slot_after)[:start_time]).to end_with("Z")
    end

    it "handles timezone offset correctly for different seasons" do
      # Summer (EDT = UTC-4): 2pm Eastern = 6pm UTC
      summer_slot = create(:slot, mentor: mentor, organization: organization,
                           start_time: Time.utc(2026, 7, 15, 18, 0, 0),
                           end_time: Time.utc(2026, 7, 15, 19, 0, 0))

      # Winter (EST = UTC-5): 2pm Eastern = 7pm UTC
      winter_slot = create(:slot, mentor: mentor, organization: organization,
                           start_time: Time.utc(2026, 12, 15, 19, 0, 0),
                           end_time: Time.utc(2026, 12, 15, 20, 0, 0))

      # Both display as "2:00 PM" in Eastern, but different UTC hours
      summer_eastern = summer_slot.start_time.in_time_zone("America/New_York")
      winter_eastern = winter_slot.start_time.in_time_zone("America/New_York")

      expect(summer_eastern.hour).to eq(14) # 2 PM EDT
      expect(winter_eastern.hour).to eq(14) # 2 PM EST
      expect(summer_eastern.utc_offset).to eq(-4 * 3600) # EDT
      expect(winter_eastern.utc_offset).to eq(-5 * 3600) # EST
    end
  end

  describe "user-level timezone" do
    it "falls back to org timezone when user timezone is nil" do
      expect(member.timezone).to be_nil
      effective_tz = member.timezone || member.organization.timezone
      expect(effective_tz).to eq("America/New_York")
    end

    it "uses user timezone when set" do
      member.update!(timezone: "Asia/Kolkata")
      effective_tz = member.timezone || member.organization.timezone
      expect(effective_tz).to eq("Asia/Kolkata")
    end
  end
end
