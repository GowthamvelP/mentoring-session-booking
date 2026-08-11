# frozen_string_literal: true

# Serializer for slot data.
# All times in ISO 8601 UTC format.
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
