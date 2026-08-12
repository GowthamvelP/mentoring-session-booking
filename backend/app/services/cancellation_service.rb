# frozen_string_literal: true

# CancellationService handles booking cancellation with:
# - Ownership verification: only the booking member can cancel
# - 1-hour cancellation window: can't cancel within 1 hour of slot start
# - Atomic transaction: booking cancelled + slot released together
# - Post-commit: cache invalidation + synchronous notification
#
# Usage:
#   result = CancellationService.call(booking: booking, user: current_user)
#   result[:success] # => true/false
#   result[:booking] # => Updated booking (on success)
class CancellationService
  include CacheInvalidation

  CANCELLATION_WINDOW = 1.hour

  def self.call(booking:, user:, reason: nil)
    new(booking: booking, user: user, reason: reason).call
  end

  def initialize(booking:, user:, reason: nil)
    @booking = booking
    @user = user
    @reason = reason
  end

  def call
    Rails.logger.debug { "CancellationService: attempting cancellation for booking=#{@booking.id}, user=#{@user.id}" }

    # 1. Ownership check
    unless @booking.member_id == @user.id
      Rails.logger.warn("CancellationService: ownership violation — user=#{@user.id} attempted to cancel booking=#{@booking.id} owned by member=#{@booking.member_id}")
      return { success: false, error: "You can only cancel your own bookings", status: :forbidden }
    end

    # 2. Status check
    unless @booking.confirmed?
      Rails.logger.warn("CancellationService: invalid status — booking=#{@booking.id} status=#{@booking.status}, expected confirmed")
      return { success: false, error: "Only confirmed bookings can be cancelled", status: :unprocessable_entity }
    end

    # 3. Cancellation window check (1 hour before slot start)
    if @booking.slot.start_time <= CANCELLATION_WINDOW.from_now
      Rails.logger.warn("CancellationService: window violation — booking=#{@booking.id} slot starts at #{@booking.slot.start_time}, too close to cancel")
      return {
        success: false,
        error: "Cannot cancel within 1 hour of session start time",
        status: :unprocessable_entity
      }
    end

    # 4. Atomic cancellation (booking + slot in single transaction)
    ActiveRecord::Base.transaction do
      @booking.update!(status: :cancelled, cancelled_at: Time.current, cancellation_reason: @reason)
      @booking.slot.update!(status: :available)
    end

    # 5. Post-commit operations
    invalidate_slot_cache(@booking.slot.mentor_id)

    # Synchronous: create in-app notifications (instant for frontend)
    NotificationService.booking_cancelled(@booking)

    Rails.logger.debug { "CancellationService: booking=#{@booking.id} cancelled successfully" }

    { success: true, booking: @booking }

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("CancellationService: unexpected error during cancellation of booking=#{@booking.id}: #{e.message}")
    { success: false, error: "Cancellation failed: #{e.message}", status: :unprocessable_entity }
  end
end
