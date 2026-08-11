# frozen_string_literal: true

# Processes booking cancellation notifications off the request path.
# Queue: critical (user-facing, time-sensitive)
# Retry: 5 attempts with exponential backoff
class BookingCancellationJob < ApplicationJob
  queue_as :critical
  sidekiq_options retry: 5, backtrace: true

  def perform(booking_id)
    booking = Booking.includes(slot: :mentor, member: []).find(booking_id)
    NotificationService.booking_cancelled(booking)
  end
end
