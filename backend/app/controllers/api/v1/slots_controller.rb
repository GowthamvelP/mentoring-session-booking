# frozen_string_literal: true

module Api
  module V1
    class SlotsController < BaseController
      def index
        mentor = User.mentors.find(params[:mentor_id])
        start_date = parse_date(params[:start_date]) || Date.current
        end_date = parse_date(params[:end_date]) || start_date + 7.days

        slots = SlotService.available_for_mentor(
          mentor_id: mentor.id,
          start_date: start_date,
          end_date: end_date
        )

        render json: {
          data: SlotBlueprint.render_as_hash(slots),
          meta: { mentor_id: mentor.id, start_date: start_date.iso8601, end_date: end_date.iso8601 }
        }
      end

      private

      def parse_date(value)
        Date.parse(value) if value.present?
      rescue Date::Error
        nil
      end
    end
  end
end
