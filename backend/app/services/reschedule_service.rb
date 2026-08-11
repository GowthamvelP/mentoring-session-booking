# frozen_string_literal: true

# RescheduleService handles atomic rescheduling with:
# - Ownership verification: only the booking member can reschedule
# - Pessimistic locking on new slot (SELECT FOR UPDATE)
# - Full atomicity: if new slot booking fails, original is preserved
# - Cache invalidation for both original and new mentor's slots
#
# Usage:
#   result = RescheduleService.call(booking: booking, new_slot_id: "uuid", user: current_user)
#   result[:success]     # => true/false
#   result[:booking]     # => New booking (on success)
#   result[:old_booking] # => Cancelled original (on success)
class RescheduleService
  def self.call(booking:, new_slot_id:, user:)
    new(booking: booking, new_slot_id: new_slot_id, user: user).call
  end

  def initialize(booking:, new_slot_id:, user:)
    @booking = booking
    @new_slot_id = new_slot_id
    @user = user
  end

  def call
    # 1. Ownership check
    unless @booking.member_id == @user.id
      return { success: false, error: "You can only reschedule your own bookings", status: :forbidden }
    end

    # 2. Status check
    unless @booking.confirmed?
      return { success: false, error: "Only confirmed bookings can be rescheduled", status: :unprocessable_entity }
    end

    # 3. Can't reschedule to the same slot
    if @booking.slot_id == @new_slot_id
      return { success: false, error: "New slot must be different from current slot", status: :unprocessable_entity }
    end

    # 4. Atomic reschedule (cancel old + book new in single transaction)
    new_booking = nil
    original_mentor_id = @booking.slot.mentor_id

    ActiveRecord::Base.transaction do
      # Lock new slot first (pessimistic)
      new_slot = Slot.lock("FOR UPDATE").find(@new_slot_id)

      unless new_slot.available?
        raise SlotUnavailableError, "New slot is no longer available"
      end

      # Cancel original booking + release original slot
      @booking.update!(status: :cancelled, cancelled_at: Time.current)
      @booking.slot.update!(status: :available)

      # Book new slot
      new_slot.update!(status: :booked)
      new_booking = Booking.create!(
        slot: new_slot,
        member: @user,
        organization: ActsAsTenant.current_tenant,
        idempotency_key: SecureRandom.uuid,
        status: :confirmed,
        booked_at: Time.current
      )
    end

    # 5. Post-commit: invalidate cache for both mentors (may be different)
    new_mentor_id = new_booking.slot.mentor_id
    invalidate_cache(original_mentor_id)
    invalidate_cache(new_mentor_id) if new_mentor_id != original_mentor_id

    enqueue_reschedule_job(@booking, new_booking)

    { success: true, booking: new_booking, old_booking: @booking }

  rescue SlotUnavailableError => e
    { success: false, error: e.message, status: :unprocessable_entity }
  rescue ActiveRecord::RecordNotFound
    { success: false, error: "New slot not found", status: :not_found }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, error: "Reschedule failed: #{e.message}", status: :unprocessable_entity }
  end

  private

  def invalidate_cache(mentor_id)
    Rails.cache.delete_matched("slots:#{mentor_id}:*")
  end

  def enqueue_reschedule_job(old_booking, new_booking)
    BookingRescheduleJob.perform_later(old_booking.id, new_booking.id)
  end

  # Custom error for slot unavailability
  class SlotUnavailableError < StandardError; end
end
