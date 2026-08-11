# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRescheduleJob, type: :job do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:old_slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
  let(:new_slot) do
    create(:slot, :booked, mentor: mentor, organization: organization,
           start_time: 4.days.from_now.beginning_of_hour,
           end_time: 4.days.from_now.beginning_of_hour + 1.hour)
  end
  let(:old_booking) { create(:booking, :cancelled, slot: old_slot, member: member, organization: organization) }
  let(:new_booking) { create(:booking, slot: new_slot, member: member, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  it "executes without error and logs the reschedule event" do
    expect { described_class.perform_now(old_booking.id, new_booking.id) }.not_to raise_error
  end

  it "raises RecordNotFound for invalid old booking ID" do
    expect { described_class.perform_now(SecureRandom.uuid, new_booking.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "raises RecordNotFound for invalid new booking ID" do
    expect { described_class.perform_now(old_booking.id, SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "is enqueued on the critical queue" do
    expect(described_class.new.queue_name).to eq("critical")
  end
end
