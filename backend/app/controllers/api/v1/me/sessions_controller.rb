# frozen_string_literal: true

module Api
  module V1
    module Me
      class SessionsController < BaseController
        # GET /api/v1/me/sessions — member's bookings
        def index
          bookings = current_user.bookings
                                 .includes(slot: { mentor: :mentor_profile })
                                 .order("slots.start_time DESC")

          pagy, records = pagy(bookings, limit: 20)

          render json: {
            data: BookingBlueprint.render_as_hash(records, view: :member_session),
            meta: pagy_metadata(pagy)
          }
        end

        # GET /api/v1/me/mentor_sessions — mentor's sessions
        def mentor_sessions
          unless current_user.mentor?
            return render_error("Only mentors can view mentor sessions", status: :forbidden)
          end

          bookings = Booking.joins(:slot)
                           .where(slots: { mentor_id: current_user.id })
                           .includes(:member, slot: :mentor)
                           .order("slots.start_time DESC")

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
