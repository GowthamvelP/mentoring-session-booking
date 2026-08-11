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
      member = booking.member
      mentor = booking.slot.mentor

      # Log notification (MVP — replace with ActionMailer in production)
      log_notification(
        type: :booking_confirmed,
        recipients: [member, mentor],
        booking: booking,
        message: "Session confirmed: #{mentor.name} with #{member.name} on #{format_time(booking.slot.start_time, booking.organization.timezone)}"
      )

      # Future: BookingMailer.confirmation_email(booking).deliver_later
      # Future: PushNotificationService.send(member, "Your session with #{mentor.name} is confirmed!")
    end

    # Notify member + mentor that a booking is cancelled
    def booking_cancelled(booking)
      member = booking.member
      mentor = booking.slot.mentor

      log_notification(
        type: :booking_cancelled,
        recipients: [member, mentor],
        booking: booking,
        message: "Session cancelled: #{mentor.name} with #{member.name} (was #{format_time(booking.slot.start_time, booking.organization.timezone)})"
      )

      # Future: BookingMailer.cancellation_email(booking).deliver_later
    end

    # Notify member + mentor that a booking is rescheduled
    def booking_rescheduled(old_booking, new_booking)
      member = new_booking.member
      mentor = new_booking.slot.mentor
      tz = new_booking.organization.timezone

      log_notification(
        type: :booking_rescheduled,
        recipients: [member, mentor],
        booking: new_booking,
        message: "Session rescheduled: #{format_time(old_booking.slot.start_time, tz)} → #{format_time(new_booking.slot.start_time, tz)}"
      )

      # Future: BookingMailer.reschedule_email(old_booking, new_booking).deliver_later
    end

    private

    def log_notification(type:, recipients:, booking:, message:)
      Rails.logger.info(
        event: "notification_sent",
        notification_type: type,
        recipient_ids: recipients.map(&:id),
        recipient_names: recipients.map(&:name),
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
