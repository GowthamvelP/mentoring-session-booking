# frozen_string_literal: true

class BookingCancellationJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(booking_id)
    booking = Booking.find(booking_id)
    Rails.logger.info(
      event: "booking_cancelled",
      booking_id: booking.id,
      member_id: booking.member_id,
      slot_id: booking.slot_id,
      mentor_id: booking.slot.mentor_id,
      cancelled_at: booking.cancelled_at&.iso8601
    )
    # Future: ActionMailer notification to member + mentor
  end
end
