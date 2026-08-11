# frozen_string_literal: true

module Api
  module V1
    class BookingsController < BaseController
      # POST /api/v1/bookings
      def create
        idempotency_key = params[:idempotency_key] || request.headers["Idempotency-Key"]

        if idempotency_key.blank?
          return render_error("idempotency_key is required", status: :unprocessable_entity,
                             details: { idempotency_key: "must be provided as param or Idempotency-Key header" })
        end

        result = BookingService.call(
          slot_id: params[:slot_id],
          member: current_user,
          idempotency_key: idempotency_key
        )

        if result[:success]
          status = result[:existing] ? :ok : :created
          render json: { data: BookingBlueprint.render_as_hash(result[:booking]) }, status: status
        else
          render_error(result[:error], status: result[:status])
        end
      end

      # PATCH /api/v1/bookings/:id/cancel
      def cancel
        booking = Booking.find(params[:id])
        result = CancellationService.call(booking: booking, user: current_user)

        if result[:success]
          render json: { data: BookingBlueprint.render_as_hash(result[:booking]) }
        else
          render_error(result[:error], status: result[:status])
        end
      end

      # POST /api/v1/bookings/:id/reschedule
      def reschedule
        booking = Booking.find(params[:id])
        result = RescheduleService.call(
          booking: booking,
          new_slot_id: params[:new_slot_id],
          user: current_user
        )

        if result[:success]
          render json: {
            data: BookingBlueprint.render_as_hash(result[:booking]),
            old_booking: BookingBlueprint.render_as_hash(result[:old_booking])
          }, status: :created
        else
          render_error(result[:error], status: result[:status])
        end
      end
    end
  end
end
