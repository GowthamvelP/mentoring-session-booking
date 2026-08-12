# frozen_string_literal: true

require "rails_helper"

RSpec.describe BaseBookingService do
  let(:organization) { create(:organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:other_member) { create(:user, :member, organization: organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:slot) { create(:slot, :booked, mentor: mentor, organization: organization) }
  let(:booking) { create(:booking, slot: slot, member: member, organization: organization, status: :confirmed) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe "#success" do
    it "returns a success hash with booking" do
      service = described_class.new
      result = service.send(:success, booking: booking)
      expect(result[:success]).to be true
      expect(result[:booking]).to eq(booking)
    end
  end

  describe "#failure" do
    it "returns a failure hash with error and status" do
      service = described_class.new
      result = service.send(:failure, error: "Something went wrong", status: :conflict)
      expect(result[:success]).to be false
      expect(result[:error]).to eq("Something went wrong")
      expect(result[:status]).to eq(:conflict)
    end
  end

  describe "#verify_ownership!" do
    it "returns nil when user owns the booking" do
      service = described_class.new
      result = service.send(:verify_ownership!, booking, member)
      expect(result).to be_nil
    end

    it "returns failure when user does not own the booking" do
      service = described_class.new
      result = service.send(:verify_ownership!, booking, other_member)
      expect(result[:success]).to be false
      expect(result[:status]).to eq(:forbidden)
    end
  end
end
