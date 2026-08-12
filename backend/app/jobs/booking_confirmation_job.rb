# frozen_string_literal: true

# Processes booking confirmation delivery off the request path.
# In-app notifications are now created synchronously in BookingService.
# This job handles future email/push delivery (ActionMailer integration).
#
# Queue: critical (user-facing, time-sensitive)
# Retry: 5 attempts with exponential backoff
class BookingConfirmationJob < ApplicationJob
  queue_as :critical
  sidekiq_options retry: 5, backtrace: true

  def perform(booking_id)
    booking = Booking.includes(slot: :mentor, member: []).find(booking_id)

    # Future: ActionMailer email delivery
    # BookingMailer.confirmation(booking).deliver_now

    Rails.logger.info(
      event: "booking_confirmation_delivered",
      booking_id: booking.id,
      channel: "in_app"
    )
  end
end
