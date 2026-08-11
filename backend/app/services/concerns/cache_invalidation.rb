# frozen_string_literal: true

# Shared concern for slot cache invalidation across booking services.
# Provides a single method that invalidates all cached slot data for a mentor
# and logs the operation at debug level for observability.
#
# Usage:
#   class MyService
#     include CacheInvalidation
#
#     def perform
#       invalidate_slot_cache(mentor_id)
#     end
#   end
module CacheInvalidation
  private

  def invalidate_slot_cache(mentor_id)
    Rails.cache.delete_matched("slots:#{mentor_id}:*")
    Rails.logger.debug { "Cache invalidated for mentor=#{mentor_id}" }
  end
end
