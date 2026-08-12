# frozen_string_literal: true

# Delivers booking reschedule emails asynchronously via ActionMailer.
# In-app notifications are created synchronously in RescheduleService.
# This job handles email delivery off the request path.
#
# Queue: critical (user-facing, time-sensitive)
# Retry: 5 attempts with exponential backoff
class BookingRescheduleJob < ApplicationJob
  queue_as :critical
  sidekiq_options retry: 5, backtrace: true

  def perform(old_booking_id, new_booking_id)
    old_booking = Booking.includes(slot: :mentor).find(old_booking_id)
    new_booking = Booking.includes(slot: :mentor, member: []).find(new_booking_id)

    # Send email to both member and mentor
    BookingMailer.reschedule(old_booking, new_booking, new_booking.member).deliver_now
    BookingMailer.reschedule(old_booking, new_booking, new_booking.slot.mentor).deliver_now

    Rails.logger.info(
      event: "booking_reschedule_email_delivered",
      old_booking_id: old_booking.id,
      new_booking_id: new_booking.id,
      recipients: [ new_booking.member.email, new_booking.slot.mentor.email ]
    )
  end
end
