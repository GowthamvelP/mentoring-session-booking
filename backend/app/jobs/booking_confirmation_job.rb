# frozen_string_literal: true

class BookingConfirmationJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(booking_id)
    booking = Booking.find(booking_id)
    Rails.logger.info(
      event: "booking_confirmed",
      booking_id: booking.id,
      member_id: booking.member_id,
      slot_id: booking.slot_id,
      mentor_id: booking.slot.mentor_id,
      start_time: booking.slot.start_time.iso8601
    )
    # Future: ActionMailer delivery to member + mentor
  end
end
