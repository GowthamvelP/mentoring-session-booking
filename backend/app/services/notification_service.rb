# frozen_string_literal: true

# NotificationService handles delivery of notifications for booking events.
# Persists notifications to the database for in-app delivery.
# Also logs for observability. In production, would additionally integrate
# with ActionMailer + SendGrid for email delivery.
#
# Usage:
#   NotificationService.booking_confirmed(booking)
#   NotificationService.booking_cancelled(booking)
#   NotificationService.booking_rescheduled(old_booking, new_booking)
class NotificationService
  class << self
    def booking_confirmed(booking)
      mentor = booking.slot.mentor
      member = booking.member
      time_str = format_time(booking.slot.start_time, booking.booked_timezone || booking.organization.timezone)

      # Notify member
      create_notification(
        user: member,
        booking: booking,
        type: "booking_confirmed",
        title: "Session Confirmed",
        body: "Your session with #{mentor.name} on #{time_str} is confirmed."
      )

      # Notify mentor
      create_notification(
        user: mentor,
        booking: booking,
        type: "booking_confirmed",
        title: "New Session Booked",
        body: "#{member.name} booked a session with you on #{time_str}."
      )
    end

    def booking_cancelled(booking)
      mentor = booking.slot.mentor
      member = booking.member

      create_notification(
        user: member,
        booking: booking,
        type: "booking_cancelled",
        title: "Session Cancelled",
        body: "Your session with #{mentor.name} has been cancelled."
      )

      create_notification(
        user: mentor,
        booking: booking,
        type: "booking_cancelled",
        title: "Session Cancelled",
        body: "#{member.name} cancelled their session with you."
      )
    end

    def booking_rescheduled(old_booking, new_booking)
      mentor = new_booking.slot.mentor
      member = new_booking.member
      tz = new_booking.booked_timezone || new_booking.organization.timezone
      old_time = format_time(old_booking.slot.start_time, tz)
      new_time = format_time(new_booking.slot.start_time, tz)

      create_notification(
        user: member,
        booking: new_booking,
        type: "booking_rescheduled",
        title: "Session Rescheduled",
        body: "Your session with #{mentor.name} moved from #{old_time} to #{new_time}."
      )

      create_notification(
        user: mentor,
        booking: new_booking,
        type: "booking_rescheduled",
        title: "Session Rescheduled",
        body: "#{member.name} rescheduled from #{old_time} to #{new_time}."
      )
    end

    private

    def create_notification(user:, booking:, type:, title:, body:)
      Notification.create!(
        user: user,
        organization: booking.organization,
        booking: booking,
        notification_type: type,
        title: title,
        body: body
      )

      Rails.logger.info(
        event: "notification_created",
        notification_type: type,
        recipient_id: user.id,
        booking_id: booking.id
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("NotificationService: failed to create notification — #{e.message}")
    end

    def format_time(time, timezone)
      time.in_time_zone(timezone).strftime("%B %d, %Y at %I:%M %p %Z")
    end
  end
end
