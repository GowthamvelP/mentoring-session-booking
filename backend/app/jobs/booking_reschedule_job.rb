# frozen_string_literal: true

# Processes booking reschedule notifications off the request path.
# Queue: critical (user-facing, time-sensitive)
# Retry: 5 attempts with exponential backoff
class BookingRescheduleJob < ApplicationJob
  queue_as :critical
  sidekiq_options retry: 5, backtrace: true

  def perform(old_booking_id, new_booking_id)
    old_booking = Booking.includes(slot: :mentor).find(old_booking_id)
    new_booking = Booking.includes(slot: :mentor, member: []).find(new_booking_id)
    NotificationService.booking_rescheduled(old_booking, new_booking)
  end
end
