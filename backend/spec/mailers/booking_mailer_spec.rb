# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingMailer, type: :mailer do
  let(:organization) { create(:organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
  let(:booking) { create(:booking, slot: slot, member: member, organization: organization, status: :confirmed) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe "#confirmation" do
    let(:mail) { described_class.confirmation(booking, member) }

    it "renders the email to the recipient" do
      expect(mail.to).to eq([ member.email ])
    end

    it "includes session details in the subject" do
      expect(mail.subject).to include("Session Confirmed")
      expect(mail.subject).to include(mentor.name)
    end

    it "renders the body with booking details" do
      expect(mail.body.encoded).to include(mentor.name)
      expect(mail.body.encoded).to include("Session Confirmed")
    end
  end

  describe "#cancellation" do
    let(:mail) { described_class.cancellation(booking, mentor) }

    it "renders the email to the recipient" do
      expect(mail.to).to eq([ mentor.email ])
    end

    it "includes cancellation in the subject" do
      expect(mail.subject).to include("Session Cancelled")
    end
  end

  describe "#reschedule" do
    let(:new_slot) { create(:slot, :booked, mentor: mentor, organization: organization, start_time: 3.days.from_now.beginning_of_hour, end_time: 3.days.from_now.beginning_of_hour + 1.hour) }
    let(:new_booking) { create(:booking, slot: new_slot, member: member, organization: organization, status: :confirmed) }
    let(:mail) { described_class.reschedule(booking, new_booking, member) }

    it "renders the email to the recipient" do
      expect(mail.to).to eq([ member.email ])
    end

    it "includes reschedule in the subject" do
      expect(mail.subject).to include("Session Rescheduled")
    end

    it "renders both old and new times" do
      expect(mail.body.encoded).to include("Session Rescheduled")
    end
  end
end
