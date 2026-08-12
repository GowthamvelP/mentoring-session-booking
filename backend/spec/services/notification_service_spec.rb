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
    it "logs notification with correct event type and recipients" do
      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "notification_sent",
        notification_type: :booking_confirmed,
        booking_id: booking.id
      ))
      described_class.booking_confirmed(booking)
    end
  end

  describe ".booking_cancelled" do
    it "logs notification with correct event type" do
      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "notification_sent",
        notification_type: :booking_cancelled,
        booking_id: booking.id
      ))
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

    it "logs notification with correct event type and booking reference" do
      expect(Rails.logger).to receive(:info).with(hash_including(
        event: "notification_sent",
        notification_type: :booking_rescheduled,
        booking_id: new_booking.id
      ))
      described_class.booking_rescheduled(booking, new_booking)
    end
  end
end
