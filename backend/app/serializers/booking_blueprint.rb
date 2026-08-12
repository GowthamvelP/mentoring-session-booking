# frozen_string_literal: true

# Serializer for booking data.
# Includes nested slot and mentor/member information.
# Views:
#   :default — full detail for individual booking responses
#   :member_session — for "My Sessions" (member perspective)
#   :mentor_session — for "My Mentor Sessions" (mentor perspective)
class BookingBlueprint < Blueprinter::Base
  identifier :id
  fields :status, :booked_timezone, :cancellation_reason

  field :booked_at do |booking|
    booking.booked_at&.utc&.iso8601
  end

  field :cancelled_at do |booking|
    booking.cancelled_at&.utc&.iso8601
  end

  field :slot do |booking|
    {
      id: booking.slot.id,
      start_time: booking.slot.start_time.utc.iso8601,
      end_time: booking.slot.end_time.utc.iso8601
    }
  end

  view :member_session do
    field :mentor do |booking|
      mentor = booking.slot.mentor
      {
        id: mentor.id,
        name: mentor.name,
        expertise: mentor.mentor_profile&.expertise || []
      }
    end
  end

  view :mentor_session do
    field :member do |booking|
      {
        id: booking.member.id,
        name: booking.member.name,
        email: booking.member.email
      }
    end
  end
end
