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
  # Deprecated IANA timezone aliases that some systems still emit
  TIMEZONE_ALIASES = {
    "Asia/Calcutta" => "Asia/Kolkata",
    "US/Eastern" => "America/New_York",
    "US/Central" => "America/Chicago",
    "US/Pacific" => "America/Los_Angeles",
    "US/Mountain" => "America/Denver"
  }.freeze

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

# Resolve the best timezone for a recipient:
# 1. User's personal timezone preference (if set)
# 2. Booking timezone (what was selected at booking time)
# 3. Organization timezone (org-level default)
# 4. UTC (safe fallback)
# This mirrors Google Calendar / Calendly behavior: each person
# sees events in THEIR timezone, not the booker's timezone.
def recipient_timezone(user, booking)
  user.timezone.presence || booking.booked_timezone || booking.organization.timezone || "UTC"
end

def format_time(time, timezone)
      # Resolve deprecated timezone aliases (e.g., Asia/Calcutta → Asia/Kolkata)
      resolved = TIMEZONE_ALIASES[timezone] || timezone
      tz = ActiveSupport::TimeZone[resolved] || ActiveSupport::TimeZone["UTC"]
      time.in_time_zone(tz).strftime("%B %d, %Y at %I:%M %p %Z")
    end
  end
end
