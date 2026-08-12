# frozen_string_literal: true

module Api
  module V1
    module Ai
      class McpController < BaseController
        # GET /api/v1/ai/mcp/tools — List available tools
        def tools
          render json: { tools: tool_definitions }
        end

        # POST /api/v1/ai/mcp/call — Execute a tool
        def call
          tool_name = params[:name]
          arguments = params[:arguments]&.to_unsafe_h || {}

          result = execute_tool(tool_name, arguments)
          render json: result
        end

        private

        def tool_definitions
          [
            {
              name: "list_mentors",
              description: "List all available mentors in the current organization with their expertise",
              input_schema: {
                type: "object",
                properties: {
                  search: { type: "string", description: "Optional search term to filter by name or expertise" }
                }
              }
            },
            {
              name: "list_slots",
              description: "List available time slots for a specific mentor",
              input_schema: {
                type: "object",
                properties: {
                  mentor_id: { type: "string", description: "UUID of the mentor" },
                  start_date: { type: "string", description: "Start date (YYYY-MM-DD), defaults to today" },
                  end_date: { type: "string", description: "End date (YYYY-MM-DD), defaults to 7 days from start" }
                },
                required: [ "mentor_id" ]
              }
            },
            {
              name: "book_slot",
              description: "Book a mentoring session slot for the current user",
              input_schema: {
                type: "object",
                properties: {
                  slot_id: { type: "string", description: "UUID of the slot to book" },
                  timezone: { type: "string", description: "IANA timezone for the booking (e.g., America/New_York)" }
                },
                required: [ "slot_id" ]
              }
            },
            {
              name: "cancel_booking",
              description: "Cancel an existing confirmed booking (must be >1 hour before session)",
              input_schema: {
                type: "object",
                properties: {
                  booking_id: { type: "string", description: "UUID of the booking to cancel" },
                  reason: { type: "string", description: "Optional cancellation reason" }
                },
                required: [ "booking_id" ]
              }
            },
            {
              name: "my_sessions",
              description: "Get the current user's upcoming and past mentoring sessions",
              input_schema: {
                type: "object",
                properties: {
                  status: { type: "string", enum: %w[confirmed cancelled all], description: "Filter by status" }
                }
              }
            }
          ]
        end

        def execute_tool(name, args)
          case name
          when "list_mentors" then tool_list_mentors(args)
          when "list_slots" then tool_list_slots(args)
          when "book_slot" then tool_book_slot(args)
          when "cancel_booking" then tool_cancel_booking(args)
          when "my_sessions" then tool_my_sessions(args)
          else
            { error: "Unknown tool: #{name}", available_tools: tool_definitions.map { |t| t[:name] } }
          end
        end

        def tool_list_mentors(args)
          mentors = User.mentors.includes(:mentor_profile)

          if args["search"].present?
            search_term = args["search"].strip
            name_ids = mentors.search_by_name(search_term).select(:id)
            expertise_ids = mentors.joins(:mentor_profile).where(
              "EXISTS (SELECT 1 FROM unnest(mentor_profiles.expertise) AS e WHERE e ILIKE ?)",
              "%#{search_term}%"
            ).select(:id)
            mentors = mentors.where(id: name_ids).or(mentors.where(id: expertise_ids))
          end

          {
            mentors: mentors.map do |m|
              {
                id: m.id,
                name: m.name,
                email: m.email,
                expertise: m.mentor_profile&.expertise || [],
                bio: m.mentor_profile&.bio
              }
            end
          }
        end

        def tool_list_slots(args)
          mentor = User.mentors.find_by(id: args["mentor_id"])
          return { error: "Mentor not found" } unless mentor

          start_date = args["start_date"] ? Date.parse(args["start_date"]) : Date.today
          end_date = args["end_date"] ? Date.parse(args["end_date"]) : start_date + 7.days

          slots = mentor.slots.where(status: :available)
                        .where(start_time: start_date.beginning_of_day..end_date.end_of_day)
                        .order(:start_time)

          {
            mentor: { id: mentor.id, name: mentor.name },
            slots: slots.map do |s|
              { id: s.id, start_time: s.start_time.utc.iso8601, end_time: s.end_time.utc.iso8601 }
            end
          }
        rescue Date::Error
          { error: "Invalid date format. Use YYYY-MM-DD." }
        end

        def tool_book_slot(args)
          result = BookingService.call(
            slot_id: args["slot_id"],
            member: current_user,
            idempotency_key: "mcp_#{args['slot_id']}_#{current_user.id}_#{Time.current.to_i}",
            timezone: args["timezone"]
          )

          if result[:success]
            booking = result[:booking]
            {
              success: true,
              booking: {
                id: booking.id,
                status: booking.status,
                slot_start: booking.slot.start_time.utc.iso8601,
                slot_end: booking.slot.end_time.utc.iso8601,
                mentor: booking.slot.mentor.name
              }
            }
          else
            { success: false, error: result[:error] }
          end
        end

        def tool_cancel_booking(args)
          booking = Booking.find_by(id: args["booking_id"])
          return { error: "Booking not found" } unless booking

          result = CancellationService.call(
            booking: booking,
            user: current_user,
            reason: args["reason"]
          )

          if result[:success]
            { success: true, message: "Booking cancelled", booking_id: booking.id }
          else
            { success: false, error: result[:error] }
          end
        end

        def tool_my_sessions(args)
          bookings = current_user.bookings.includes(slot: { mentor: :mentor_profile })
                                 .order("slots.start_time ASC")

          if args["status"].present? && args["status"] != "all"
            bookings = bookings.where(status: args["status"])
          end

          {
            sessions: bookings.map do |b|
              {
                id: b.id,
                status: b.status,
                start_time: b.slot.start_time.utc.iso8601,
                end_time: b.slot.end_time.utc.iso8601,
                mentor: b.slot.mentor.name,
                booked_timezone: b.booked_timezone
              }
            end
          }
        end
      end
    end
  end
end
