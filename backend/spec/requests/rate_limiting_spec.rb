# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rate Limiting", type: :request do
  let(:organization) { create(:organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:slot) { create(:slot, mentor: mentor, organization: organization) }
  let(:headers) { { "X-User-Id" => member.id, "X-Org-Id" => organization.id } }

  before do
    # Clear rate limiting cache between tests
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
  end

  describe "POST /api/v1/bookings rate limit" do
    it "allows requests within the limit" do
      post "/api/v1/bookings",
           params: { slot_id: slot.id, idempotency_key: SecureRandom.uuid },
           headers: headers

      expect(response.status).not_to eq(429)
    end
  end

  describe "GET /api/v1/mentors/:mentor_id/slots rate limit" do
    it "allows requests within the limit" do
      get "/api/v1/mentors/#{mentor.id}/slots", headers: headers
      expect(response.status).not_to eq(429)
    end
  end
end
