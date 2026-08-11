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
  def self.call(slot_id:, member:, idempotency_key:)
    new(slot_id: slot_id, member: member, idempotency_key: idempotency_key).call
  end

  def initialize(slot_id:, member:, idempotency_key:)
    @slot_id = slot_id
    @member = member
    @idempotency_key = idempotency_key
  end

  def call
    # 1. Idempotency check — return existing booking if key already used
    existing = Booking.find_by(idempotency_key: @idempotency_key)
    return { success: true, booking: existing, existing: true } if existing

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
        booked_at: Time.current
      )
    end

    # 3. Post-commit operations (outside transaction)
    invalidate_cache(booking.slot.mentor_id)
    enqueue_confirmation_job(booking)

    { success: true, booking: booking, existing: false }

  rescue SlotUnavailableError => e
    { success: false, error: e.message, status: :conflict }
  rescue ActiveRecord::RecordNotFound
    { success: false, error: "Slot not found", status: :not_found }
  rescue ActiveRecord::RecordInvalid => e
    # Handle unique constraint violation on idempotency_key (race condition)
    existing = Booking.find_by(idempotency_key: @idempotency_key)
    if existing
      { success: true, booking: existing, existing: true }
    else
      { success: false, error: e.message, status: :unprocessable_entity }
    end
  end

  private

  def invalidate_cache(mentor_id)
    Rails.cache.delete_matched("slots:#{mentor_id}:*")
  end

  def enqueue_confirmation_job(booking)
    BookingConfirmationJob.perform_later(booking.id)
  end

  # Custom error for slot unavailability (keeps exception hierarchy clean)
  class SlotUnavailableError < StandardError; end
end
