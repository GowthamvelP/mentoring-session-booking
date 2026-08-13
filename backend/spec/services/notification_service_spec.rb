# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationService, type: :service do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
  let(:booking) { create(:booking, slot: slot, member: member, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe ".booking_confirmed" do
    it "creates notifications for member and mentor" do
      expect {
        described_class.booking_confirmed(booking)
      }.to change(Notification, :count).by(2)
    end

    it "logs notification_created events" do
      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "notification_created",
        notification_type: "booking_confirmed",
        booking_id: booking.id
      )).twice
      described_class.booking_confirmed(booking)
    end
  end

  describe ".booking_cancelled" do
    it "creates notifications for member and mentor" do
      expect {
        described_class.booking_cancelled(booking)
      }.to change(Notification, :count).by(2)
    end

    it "logs notification_created events" do
      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "notification_created",
        notification_type: "booking_cancelled",
        booking_id: booking.id
      )).twice
      described_class.booking_cancelled(booking)
    end
  end

  describe ".booking_rescheduled" do
    let(:new_slot) do
      create(:slot, :booked, mentor: mentor, organization: organization,
             start_time: 5.days.from_now.beginning_of_hour,
             end_time: 5.days.from_now.beginning_of_hour + 1.hour)
    end
    let(:new_booking) { create(:booking, slot: new_slot, member: member, organization: organization) }

    it "creates notifications for member and mentor" do
      expect {
        described_class.booking_rescheduled(booking, new_booking)
      }.to change(Notification, :count).by(2)
    end

    it "logs notification_created events" do
      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "notification_created",
        notification_type: "booking_rescheduled",
        booking_id: new_booking.id
      )).twice
      described_class.booking_rescheduled(booking, new_booking)
    end
  end


  describe "recipient timezone handling" do
    let(:mentor_with_tz) { create(:user, :mentor, organization: organization, timezone: "America/Chicago") }
    let(:member_with_tz) { create(:user, :member, organization: organization, timezone: "Asia/Kolkata") }
    let(:tz_slot) { create(:slot, :booked, mentor: mentor_with_tz, organization: organization) }
    let(:tz_booking) { create(:booking, slot: tz_slot, member: member_with_tz, organization: organization, booked_timezone: "Asia/Kolkata") }

    it "formats member notification in member timezone (IST)" do
      described_class.booking_confirmed(tz_booking)
      member_notification = Notification.find_by(user: member_with_tz, notification_type: "booking_confirmed")
      expect(member_notification.body).to include("IST")
    end

    it "formats mentor notification in mentor timezone (CDT/CST)" do
      described_class.booking_confirmed(tz_booking)
      mentor_notification = Notification.find_by(user: mentor_with_tz, notification_type: "booking_confirmed")
      expect(mentor_notification.body).to satisfy("include CDT or CST") { |body| body.include?("CDT") || body.include?("CST") }
    end

    it "member and mentor see different time representations" do
      described_class.booking_confirmed(tz_booking)
      member_notif = Notification.find_by(user: member_with_tz, notification_type: "booking_confirmed")
      mentor_notif = Notification.find_by(user: mentor_with_tz, notification_type: "booking_confirmed")
      expect(member_notif.body).not_to eq(mentor_notif.body)
    end

    it "falls back to booking timezone when user has no timezone" do
      member_no_tz = create(:user, :member, organization: organization, timezone: nil)
      no_tz_slot = create(:slot, :booked, mentor: mentor_with_tz, organization: organization)
      no_tz_booking = create(:booking, slot: no_tz_slot, member: member_no_tz, organization: organization, booked_timezone: "Europe/London")
      described_class.booking_confirmed(no_tz_booking)
      member_notif = Notification.find_by(user: member_no_tz, notification_type: "booking_confirmed")
      expect(member_notif.body).to satisfy("include BST or GMT") { |body| body.include?("BST") || body.include?("GMT") }
    end
  end
end
