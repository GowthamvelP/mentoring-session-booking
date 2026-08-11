require "rails_helper"

RSpec.describe Booking, type: :model do
  let(:organization) { create(:organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe "associations" do
    it { is_expected.to belong_to(:slot) }
    it { is_expected.to belong_to(:member).class_name("User") }
  end

  describe "validations" do
    subject { build(:booking, organization: organization) }

    it { is_expected.to validate_presence_of(:idempotency_key) }
    it { is_expected.to validate_uniqueness_of(:idempotency_key) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:booked_at) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(confirmed: "confirmed", cancelled: "cancelled", completed: "completed").backed_by_column_of_type(:string) }
  end

  describe "scopes" do
    let(:mentor) { create(:user, :mentor, organization: organization) }
    let(:member) { create(:user, :member, organization: organization) }
    let(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
    let!(:active_booking) { create(:booking, slot: slot, member: member, organization: organization) }
    let!(:cancelled_booking) do
      create(:booking, :cancelled,
             slot: create(:slot, :booked, mentor: mentor, organization: organization,
                          start_time: 3.days.from_now.beginning_of_hour,
                          end_time: 3.days.from_now.beginning_of_hour + 1.hour),
             member: member, organization: organization)
    end

    it ".active returns only confirmed bookings" do
      expect(Booking.active).to include(active_booking)
      expect(Booking.active).not_to include(cancelled_booking)
    end
  end
end
