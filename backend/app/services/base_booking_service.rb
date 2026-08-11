# frozen_string_literal: true

# Base class for booking-related services.
# Provides shared lifecycle: validate → execute → post_commit
# Includes CacheInvalidation concern and common result helpers.
#
# Subclasses can use:
#   success(booking:, **extras) → standard success hash
#   failure(error:, status:) → standard failure hash
#   verify_ownership!(booking, user) → returns failure hash or nil
class BaseBookingService
  include CacheInvalidation

  def self.call(**args)
    new(**args).call
  end

  private

  def success(booking:, **extras)
    { success: true, booking: booking, **extras }
  end

  def failure(error:, status:)
    { success: false, error: error, status: status }
  end

  def verify_ownership!(booking, user)
    unless booking.member_id == user.id
      return failure(error: "You can only modify your own bookings", status: :forbidden)
    end
    nil
  end
end
