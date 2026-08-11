require "rails_helper"

RSpec.describe Slot, type: :model do
  let(:organization) { create(:organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe "associations" do
    it { is_expected.to belong_to(:mentor).class_name("User") }
    it { is_expected.to have_one(:booking).dependent(:restrict_with_error) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:start_time) }
    it { is_expected.to validate_presence_of(:end_time) }
    it { is_expected.to validate_presence_of(:status) }

    context "end_after_start validation" do
      let(:mentor) { create(:user, :mentor, organization: organization) }

      it "is invalid when end_time is before start_time" do
        slot = build(:slot, mentor: mentor, organization: organization,
                     start_time: 2.hours.from_now, end_time: 1.hour.from_now)
        expect(slot).not_to be_valid
        expect(slot.errors[:end_time]).to include("must be after start time")
      end

      it "is invalid when end_time equals start_time" do
        time = 1.hour.from_now
        slot = build(:slot, mentor: mentor, organization: organization,
                     start_time: time, end_time: time)
        expect(slot).not_to be_valid
      end

      it "is valid when end_time is after start_time" do
        slot = build(:slot, mentor: mentor, organization: organization,
                     start_time: 1.hour.from_now, end_time: 2.hours.from_now)
        expect(slot).to be_valid
      end
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(available: "available", booked: "booked").backed_by_column_of_type(:string) }
  end

  describe "scopes" do
    let(:mentor) { create(:user, :mentor, organization: organization) }
    let!(:available_slot) { create(:slot, mentor: mentor, organization: organization, status: :available) }
    let!(:booked_slot) { create(:slot, :booked, mentor: mentor, organization: organization, start_time: 2.days.from_now.beginning_of_hour, end_time: 2.days.from_now.beginning_of_hour + 1.hour) }
    let!(:past_slot) { create(:slot, :past, mentor: mentor, organization: organization) }

    it ".available returns only available slots" do
      expect(Slot.available).to include(available_slot)
      expect(Slot.available).not_to include(booked_slot)
    end

    it ".future returns only future slots" do
      expect(Slot.future).to include(available_slot)
      expect(Slot.future).not_to include(past_slot)
    end
  end
end
