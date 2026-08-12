# frozen_string_literal: true

# Delivers booking cancellation emails asynchronously via ActionMailer.
# In-app notifications are created synchronously in CancellationService.
# This job handles email delivery off the request path.
#
# Queue: critical (user-facing, time-sensitive)
# Retry: 5 attempts with exponential backoff
class BookingCancellationJob < ApplicationJob
  queue_as :critical
  sidekiq_options retry: 5, backtrace: true

  def perform(booking_id)
    booking = Booking.includes(slot: :mentor, member: []).find(booking_id)

    # Send email to both member and mentor
    BookingMailer.cancellation(booking, booking.member).deliver_now
    BookingMailer.cancellation(booking, booking.slot.mentor).deliver_now

    Rails.logger.info(
      event: "booking_cancellation_email_delivered",
      booking_id: booking.id,
      recipients: [ booking.member.email, booking.slot.mentor.email ]
    )
  end
end
