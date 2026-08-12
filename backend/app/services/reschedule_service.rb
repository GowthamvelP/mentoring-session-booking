# frozen_string_literal: true

# RescheduleService handles atomic rescheduling with:
# - Ownership verification: only the booking member can reschedule
# - Pessimistic locking on new slot (SELECT FOR UPDATE)
# - Full atomicity: if new slot booking fails, original is preserved
# - Cache invalidation for both original and new mentor's slots
# - Synchronous in-app notification creation
#
# Usage:
#   result = RescheduleService.call(booking: booking, new_slot_id: "uuid", user: current_user)
#   result[:success]     # => true/false
#   result[:booking]     # => New booking (on success)
#   result[:old_booking] # => Cancelled original (on success)
class RescheduleService
  include CacheInvalidation

  def self.call(booking:, new_slot_id:, user:, timezone: nil)
    new(booking: booking, new_slot_id: new_slot_id, user: user, timezone: timezone).call
  end

  def initialize(booking:, new_slot_id:, user:, timezone: nil)
    @booking = booking
    @new_slot_id = new_slot_id
    @user = user
    @timezone = timezone
  end

  def call
    Rails.logger.debug { "RescheduleService: attempting reschedule for booking=#{@booking.id}, new_slot=#{@new_slot_id}, user=#{@user.id}" }

    # 1. Ownership check
    unless @booking.member_id == @user.id
      Rails.logger.warn("RescheduleService: ownership violation — user=#{@user.id} attempted to reschedule booking=#{@booking.id} owned by member=#{@booking.member_id}")
      return { success: false, error: "You can only reschedule your own bookings", status: :forbidden }
    end

    # 2. Status check
    unless @booking.confirmed?
      Rails.logger.warn("RescheduleService: invalid status — booking=#{@booking.id} status=#{@booking.status}, expected confirmed")
      return { success: false, error: "Only confirmed bookings can be rescheduled", status: :unprocessable_entity }
    end

    # 3. Can't reschedule to the same slot
    if @booking.slot_id == @new_slot_id
      Rails.logger.warn("RescheduleService: same slot — booking=#{@booking.id} already on slot=#{@new_slot_id}")
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
        booked_at: Time.current,
        booked_timezone: @timezone || @booking.booked_timezone || ActsAsTenant.current_tenant&.timezone || "UTC"
      )
    end

    # 5. Post-commit: invalidate cache for both mentors (may be different)
    new_mentor_id = new_booking.slot.mentor_id
    invalidate_slot_cache(original_mentor_id)
    invalidate_slot_cache(new_mentor_id) if new_mentor_id != original_mentor_id

    # Synchronous: create in-app notifications (instant for frontend)
    NotificationService.booking_rescheduled(@booking, new_booking)

    # Async: email delivery
    BookingRescheduleJob.perform_later(@booking.id, new_booking.id)

    Rails.logger.debug { "RescheduleService: reschedule successful — old_booking=#{@booking.id}, new_booking=#{new_booking.id}" }

    { success: true, booking: new_booking, old_booking: @booking }

  rescue SlotUnavailableError => e
    Rails.logger.warn("RescheduleService: slot conflict for new_slot=#{@new_slot_id} — #{e.message}")
    { success: false, error: e.message, status: :unprocessable_entity }
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("RescheduleService: new slot not found, slot_id=#{@new_slot_id}")
    { success: false, error: "New slot not found", status: :not_found }
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("RescheduleService: unexpected error during reschedule of booking=#{@booking.id}: #{e.message}")
    { success: false, error: "Reschedule failed: #{e.message}", status: :unprocessable_entity }
  end

  private

  # Custom error for slot unavailability
  class SlotUnavailableError < StandardError; end
end
