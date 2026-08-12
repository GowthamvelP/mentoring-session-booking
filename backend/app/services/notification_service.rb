# frozen_string_literal: true

# NotificationService handles delivery of notifications for booking events.
# Currently logs to Rails.logger (MVP). In production, this would integrate
# with ActionMailer + SendGrid for email, and/or Firebase/OneSignal for push.
#
# Usage:
#   NotificationService.booking_confirmed(booking)
#   NotificationService.booking_cancelled(booking)
#   NotificationService.booking_rescheduled(old_booking, new_booking)
class NotificationService
  class << self
    # Notify member + mentor that a booking is confirmed
    def booking_confirmed(booking)
      notify(:booking_confirmed, booking) do |b|
        mentor = b.slot.mentor
        "Session confirmed: #{mentor.name} with #{b.member.name} on #{format_time(b.slot.start_time, b.organization.timezone)}"
      end
    end

    # Notify member + mentor that a booking is cancelled
    def booking_cancelled(booking)
      notify(:booking_cancelled, booking) do |b|
        "Session cancelled: #{b.slot.mentor.name} with #{b.member.name}"
      end
    end

    # Notify member + mentor that a booking is rescheduled
    def booking_rescheduled(old_booking, new_booking)
      tz = new_booking.organization.timezone
      notify(:booking_rescheduled, new_booking, recipients_from: [ new_booking.member, new_booking.slot.mentor ]) do |_b|
        "Session rescheduled: #{format_time(old_booking.slot.start_time, tz)} → #{format_time(new_booking.slot.start_time, tz)}"
      end
    end

    private

    def notify(type, booking, recipients_from: nil)
      recipients = recipients_from || [ booking.member, booking.slot.mentor ]
      message = yield(booking)

      Rails.logger.info(
        event: "notification_sent",
        notification_type: type,
        recipient_ids: recipients.map(&:id),
        booking_id: booking.id,
        organization_id: booking.organization_id,
        message: message
      )
    end

    def format_time(time, timezone)
      time.in_time_zone(timezone).strftime("%B %d, %Y at %I:%M %p %Z")
    end
  end
end
