# frozen_string_literal: true

# Delivers booking confirmation emails asynchronously via ActionMailer.
# In-app notifications are created synchronously in BookingService.
# This job handles email delivery off the request path.
#
# Queue: critical (user-facing, time-sensitive)
# Retry: 5 attempts with exponential backoff
class BookingConfirmationJob < ApplicationJob
  queue_as :critical
  sidekiq_options retry: 5, backtrace: true

  def perform(booking_id)
    booking = Booking.includes(slot: :mentor, member: []).find(booking_id)
    return unless booking.confirmed?

    # Send email to both member and mentor
    BookingMailer.confirmation(booking, booking.member).deliver_now
    BookingMailer.confirmation(booking, booking.slot.mentor).deliver_now

    Rails.logger.info(
      event: "booking_email_delivered",
      booking_id: booking.id,
      recipients: [ booking.member.email, booking.slot.mentor.email ]
    )
  end
end
