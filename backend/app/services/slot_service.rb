# frozen_string_literal: true

# SlotService provides cached access to available slots.
# Uses Rails.cache (Redis-backed) with cache-aside pattern:
# - Check cache first (cache key includes mentor_id + date range)
# - On miss: query DB, cache result with 300s TTL
# - On mutation: invalidate via delete_matched
class SlotService
  CACHE_TTL = 5.minutes

  def self.available_for_mentor(mentor_id:, start_date:, end_date:)
    cache_key = "slots:#{mentor_id}:#{start_date}:#{end_date}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      Slot.where(mentor_id: mentor_id)
          .available
          .future
          .for_date_range(start_date, end_date)
          .order(:start_time)
          .to_a
    end
  end

  def self.invalidate_for_mentor(mentor_id)
    Rails.cache.delete_matched("slots:#{mentor_id}:*")
  end
end
