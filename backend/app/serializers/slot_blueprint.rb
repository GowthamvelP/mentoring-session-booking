# frozen_string_literal: true

# Serializer for slot data.
# All times in ISO 8601 UTC format.
#
# The API always returns UTC. Frontend handles display conversion using:
# - User's explicit timezone (if set)
# - Browser's detected timezone (Intl.DateTimeFormat().resolvedOptions().timeZone)
# - Organization's default timezone (fallback)
class SlotBlueprint < Blueprinter::Base
  identifier :id

  field :start_time do |slot|
    slot.start_time.utc.iso8601
  end

  field :end_time do |slot|
    slot.end_time.utc.iso8601
  end

  field :status
end
