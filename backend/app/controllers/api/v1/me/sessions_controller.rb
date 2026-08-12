# frozen_string_literal: true

module Api
  module V1
    module Me
      class SessionsController < BaseController
        # GET /api/v1/me/sessions — member's bookings
        def index
          bookings = current_user.bookings
                                 .includes(slot: { mentor: :mentor_profile })
                                 .order("slots.start_time ASC")

          pagy, records = pagy(bookings, limit: 20)

          render json: {
            data: BookingBlueprint.render_as_hash(records, view: :member_session),
            meta: pagy_metadata(pagy)
          }
        end

        # PATCH /api/v1/me/timezone
        def update_timezone
          timezone = params[:timezone]

          unless timezone.present? && Time.find_zone(timezone)
            return render_error("Invalid timezone", status: :unprocessable_entity,
                               details: { timezone: "Must be a valid IANA timezone (e.g., 'America/New_York')" })
          end

          current_user.update!(timezone: timezone)
          render json: { timezone: current_user.timezone, message: "Timezone updated" }
        end

        # GET /api/v1/me/mentor_sessions — mentor's sessions
        def mentor_sessions
          unless current_user.mentor?
            return render_error("Only mentors can view mentor sessions", status: :forbidden)
          end

          bookings = Booking.joins(:slot)
                           .where(slots: { mentor_id: current_user.id })
                           .includes(:member, slot: :mentor)
                           .order("slots.start_time ASC")

          pagy, records = pagy(bookings, limit: 20)

          render json: {
            data: BookingBlueprint.render_as_hash(records, view: :mentor_session),
            meta: pagy_metadata(pagy)
          }
        end
      end
    end
  end
end
