# frozen_string_literal: true

# Processes booking reschedule delivery off the request path.
# In-app notifications are now created synchronously in RescheduleService.
# This job handles future email/push delivery (ActionMailer integration).
#
# Queue: critical (user-facing, time-sensitive)
# Retry: 5 attempts with exponential backoff
class BookingRescheduleJob < ApplicationJob
  queue_as :critical
  sidekiq_options retry: 5, backtrace: true

  def perform(old_booking_id, new_booking_id)
    old_booking = Booking.includes(slot: :mentor).find(old_booking_id)
    new_booking = Booking.includes(slot: :mentor, member: []).find(new_booking_id)

    # Future: ActionMailer email delivery
    # BookingMailer.reschedule(old_booking, new_booking).deliver_now

    Rails.logger.info(
      event: "booking_reschedule_delivered",
      old_booking_id: old_booking.id,
      new_booking_id: new_booking.id,
      channel: "in_app"
    )
  end
end
