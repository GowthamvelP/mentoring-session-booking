# frozen_string_literal: true

# CancellationService handles booking cancellation with:
# - Ownership verification: only the booking member can cancel
# - 1-hour cancellation window: can't cancel within 1 hour of slot start
# - Atomic transaction: booking cancelled + slot released together
# - Post-commit: cache invalidation + async job enqueue
#
# Usage:
#   result = CancellationService.call(booking: booking, user: current_user)
#   result[:success] # => true/false
#   result[:booking] # => Updated booking (on success)
class CancellationService
  CANCELLATION_WINDOW = 1.hour

  def self.call(booking:, user:)
    new(booking: booking, user: user).call
  end

  def initialize(booking:, user:)
    @booking = booking
    @user = user
  end

  def call
    # 1. Ownership check
    unless @booking.member_id == @user.id
      return { success: false, error: "You can only cancel your own bookings", status: :forbidden }
    end

    # 2. Status check
    unless @booking.confirmed?
      return { success: false, error: "Only confirmed bookings can be cancelled", status: :unprocessable_entity }
    end

    # 3. Cancellation window check (1 hour before slot start)
    if @booking.slot.start_time <= CANCELLATION_WINDOW.from_now
      return {
        success: false,
        error: "Cannot cancel within 1 hour of session start time",
        status: :unprocessable_entity
      }
    end

    # 4. Atomic cancellation (booking + slot in single transaction)
    ActiveRecord::Base.transaction do
      @booking.update!(status: :cancelled, cancelled_at: Time.current)
      @booking.slot.update!(status: :available)
    end

    # 5. Post-commit operations
    invalidate_cache(@booking.slot.mentor_id)
    enqueue_cancellation_job(@booking)

    { success: true, booking: @booking }

  rescue ActiveRecord::RecordInvalid => e
    { success: false, error: "Cancellation failed: #{e.message}", status: :unprocessable_entity }
  end

  private

  def invalidate_cache(mentor_id)
    Rails.cache.delete_matched("slots:#{mentor_id}:*")
  end

  def enqueue_cancellation_job(booking)
    BookingCancellationJob.perform_later(booking.id)
  end
end
