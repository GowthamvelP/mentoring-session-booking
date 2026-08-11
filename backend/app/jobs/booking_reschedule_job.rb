# frozen_string_literal: true

class BookingRescheduleJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(old_booking_id, new_booking_id)
    old_booking = Booking.find(old_booking_id)
    new_booking = Booking.find(new_booking_id)
    Rails.logger.info(
      event: "booking_rescheduled",
      old_booking_id: old_booking.id,
      new_booking_id: new_booking.id,
      member_id: new_booking.member_id,
      old_slot_start: old_booking.slot.start_time.iso8601,
      new_slot_start: new_booking.slot.start_time.iso8601
    )
    # Future: ActionMailer notification with old + new times
  end
end
