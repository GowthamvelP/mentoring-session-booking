# frozen_string_literal: true

require "rails_helper"

RSpec.describe CacheInvalidation do
  let(:test_class) do
    Class.new do
      include CacheInvalidation
      public :invalidate_slot_cache
    end
  end

  let(:service) { test_class.new }

  describe "#invalidate_slot_cache" do
    let(:mentor_id) { SecureRandom.uuid }

    it "calls delete_matched with the correct pattern" do
      expect(Rails.cache).to receive(:delete_matched).with("slots:#{mentor_id}:*")
      service.invalidate_slot_cache(mentor_id)
    end

    it "logs cache invalidation at debug level" do
      allow(Rails.cache).to receive(:delete_matched)
      expect(Rails.logger).to receive(:debug)
      service.invalidate_slot_cache(mentor_id)
    end
  end
end
