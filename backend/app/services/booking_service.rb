# frozen_string_literal: true

# BookingService handles the creation of a new booking with:
# - Idempotency: duplicate requests with same key return existing booking
# - Pessimistic locking: SELECT FOR UPDATE prevents double-booking
# - Atomic transaction: slot update + booking creation committed together
# - Post-commit: cache invalidation + async job enqueue
#
# Usage:
#   result = BookingService.call(slot_id: "uuid", member: user, idempotency_key: "uuid")
#   result[:success] # => true/false
#   result[:booking] # => Booking record (on success)
#   result[:error]   # => Error message (on failure)
#   result[:status]  # => HTTP status symbol (on failure)
class BookingService
  include CacheInvalidation

  def self.call(slot_id:, member:, idempotency_key:, timezone: nil)
    new(slot_id: slot_id, member: member, idempotency_key: idempotency_key, timezone: timezone).call
  end

  def initialize(slot_id:, member:, idempotency_key:, timezone: nil)
    @slot_id = slot_id
    @member = member
    @idempotency_key = idempotency_key
    @timezone = timezone
  end

  def call
    Rails.logger.debug { "BookingService: checking idempotency for key=#{@idempotency_key}" }

    # 1. Idempotency check — return existing booking if key already used
    existing = Booking.find_by(idempotency_key: @idempotency_key)
    if existing
      Rails.logger.debug { "BookingService: idempotent replay for key=#{@idempotency_key}, booking=#{existing.id}" }
      return { success: true, booking: existing, existing: true }
    end

    # 1.5. Per-member booking limit check
    max_bookings = ActsAsTenant.current_tenant&.max_active_bookings
    if max_bookings && @member.bookings.active.count >= max_bookings
      Rails.logger.warn("BookingService: booking limit reached for member=#{@member.id}, limit=#{max_bookings}")
      return { success: false, error: "Booking limit reached (maximum #{max_bookings} active sessions)", status: :unprocessable_entity }
    end

    # 2. Pessimistic lock + atomic booking
    booking = nil

    ActiveRecord::Base.transaction do
      # SELECT FOR UPDATE — locks the row until transaction commits
      # Single-row point lock: cannot deadlock, sub-50ms hold time
      slot = Slot.lock("FOR UPDATE").find(@slot_id)

      # Validate slot is available
      unless slot.available?
        raise SlotUnavailableError, "Slot is no longer available (current status: #{slot.status})"
      end

      # Transition slot to booked
      slot.update!(status: :booked)

      # Create booking record
      booking = Booking.create!(
        slot: slot,
        member: @member,
        organization: ActsAsTenant.current_tenant,
        idempotency_key: @idempotency_key,
        status: :confirmed,
        booked_at: Time.current,
        booked_timezone: @timezone || ActsAsTenant.current_tenant&.timezone || "UTC"
      )
    end

    # 3. Post-commit operations (outside transaction)
    invalidate_slot_cache(booking.slot.mentor_id)
    enqueue_confirmation_job(booking)
    enqueue_brief_job(booking)

    Rails.logger.debug { "BookingService: booking created successfully, id=#{booking.id}, slot=#{@slot_id}" }

    { success: true, booking: booking, existing: false }

  rescue SlotUnavailableError => e
    Rails.logger.warn("BookingService: slot conflict for slot=#{@slot_id}, member=#{@member.id} — #{e.message}")
    { success: false, error: e.message, status: :conflict }
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("BookingService: slot not found, slot_id=#{@slot_id}")
    { success: false, error: "Slot not found", status: :not_found }
  rescue ActiveRecord::RecordInvalid => e
    # Handle unique constraint violation on idempotency_key (race condition)
    existing = Booking.find_by(idempotency_key: @idempotency_key)
    if existing
      { success: true, booking: existing, existing: true }
    else
      Rails.logger.error("BookingService: unexpected validation error during booking: #{e.message}")
      { success: false, error: e.message, status: :unprocessable_entity }
    end
  end

  private

  def enqueue_confirmation_job(booking)
    BookingConfirmationJob.perform_later(booking.id)
  end

  def enqueue_brief_job(booking)
    BookingBriefJob.perform_later(booking.id)
  end

  # Custom error for slot unavailability (keeps exception hierarchy clean)
  class SlotUnavailableError < StandardError; end
end
