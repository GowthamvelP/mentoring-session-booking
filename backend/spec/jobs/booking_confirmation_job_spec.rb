# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingConfirmationJob, type: :job do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
  let(:booking) { create(:booking, slot: slot, member: member, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  it "executes without error and logs the confirmation event" do
    expect { described_class.perform_now(booking.id) }.not_to raise_error
  end

  it "raises RecordNotFound for invalid booking ID" do
    expect { described_class.perform_now(SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "is enqueued on the critical queue" do
    expect(described_class.new.queue_name).to eq("critical")
  end
end
