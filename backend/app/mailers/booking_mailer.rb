# frozen_string_literal: true

# BookingMailer sends transactional emails for booking lifecycle events.
# In development: emails are captured by letter_opener_web (visible at /letter_opener)
# In production: delivered via SMTP (SendGrid, Mailgun, or SES configured via env vars)
class BookingMailer < ApplicationMailer
  default from: "notifications@mentorbook.io"

  # Sent to both member and mentor when a booking is confirmed
  def confirmation(booking, recipient)
    @booking = booking
    @mentor = booking.slot.mentor
    @member = booking.member
    @slot = booking.slot
    @timezone = recipient.timezone.presence || recipient.timezone.presence || booking.booked_timezone || booking.organization.timezone || "UTC" || "UTC"
    @time_display = format_time(@slot.start_time, @timezone)

    mail(
      to: recipient.email,
      subject: "Session Confirmed — #{@mentor.name} & #{@member.name} on #{@time_display}"
    )
  end

  # Sent to both member and mentor when a booking is cancelled
  def cancellation(booking, recipient)
    @booking = booking
    @mentor = booking.slot.mentor
    @member = booking.member
    @slot = booking.slot
    @timezone = recipient.timezone.presence || booking.booked_timezone || booking.organization.timezone || "UTC"
    @time_display = format_time(@slot.start_time, @timezone)
    @reason = booking.cancellation_reason

    mail(
      to: recipient.email,
      subject: "Session Cancelled — #{@mentor.name} & #{@member.name}"
    )
  end

  # Sent to both member and mentor when a booking is rescheduled
  def reschedule(old_booking, new_booking, recipient)
    @old_booking = old_booking
    @new_booking = new_booking
    @mentor = new_booking.slot.mentor
    @member = new_booking.member
    @timezone = recipient.timezone.presence || new_booking.booked_timezone || new_booking.organization.timezone || "UTC"
    @old_time = format_time(old_booking.slot.start_time, @timezone)
    @new_time = format_time(new_booking.slot.start_time, @timezone)

    mail(
      to: recipient.email,
      subject: "Session Rescheduled — #{@mentor.name} & #{@member.name}"
    )
  end

  private

  def format_time(time, timezone)
    resolved = NotificationService::TIMEZONE_ALIASES[timezone] || timezone
    tz = ActiveSupport::TimeZone[resolved] || ActiveSupport::TimeZone["UTC"]
    time.in_time_zone(tz).strftime("%B %d, %Y at %I:%M %p %Z")
  end
end
