# frozen_string_literal: true

module Api
  module V1
    module Ai
      class ContextController < BaseController
        skip_before_action :authenticate_user!
        skip_before_action :set_tenant!, raise: false

        def show
          render json: {
            system: system_meta,
            schema: schema_definition,
            conventions: conventions,
            endpoints: api_endpoints,
            ai_features: ai_feature_flags
          }
        end

        private

        def system_meta
          {
            name: "MentorBook Mentoring Booking",
            version: "1.0.0",
            stack: [ "Rails 8 API-only", "PostgreSQL 16", "Redis 7", "Sidekiq 7", "React 19 + Vite" ],
            environment: Rails.env
          }
        end

        def schema_definition
          {
            organizations: {
              fields: %w[id name timezone max_active_bookings],
              tenancy: "root_scope"
            },
            users: {
              fields: %w[id organization_id email name role timezone],
              roles: %w[member mentor],
              tenancy: "organization_id"
            },
            slots: {
              fields: %w[id mentor_id start_time end_time status buffer_minutes],
              statuses: %w[available booked],
              locking: "pessimistic (SELECT FOR UPDATE)",
              tenancy: "via mentor -> user -> organization_id"
            },
            bookings: {
              fields: %w[id slot_id member_id status idempotency_key booked_at booked_timezone cancellation_reason],
              statuses: %w[confirmed cancelled],
              idempotency: "UNIQUE(idempotency_key)",
              tenancy: "organization_id"
            }
          }
        end

        def conventions
          {
            write_path: "Controller -> Service -> Model (transaction)",
            caching: "Cache-aside with Redis, pattern-based invalidation (slots:mentor_id:*)",
            async: "Sidekiq jobs for notifications, cache invalidation",
            locking: "Pessimistic locking on slots (FOR UPDATE); idempotency on bookings",
            search: "pg_trgm GIN indexes for name; GIN array index for expertise"
          }
        end

        def api_endpoints
          [
            { method: "GET", path: "/api/v1/mentors", auth: "org-scoped", description: "List/search mentors" },
            { method: "GET", path: "/api/v1/mentors/:id/slots", auth: "org-scoped", description: "Available slots for mentor" },
            { method: "POST", path: "/api/v1/bookings", auth: "org-scoped + idempotency", description: "Book a slot" },
            { method: "PATCH", path: "/api/v1/bookings/:id/cancel", auth: "org-scoped", description: "Cancel booking" },
            { method: "POST", path: "/api/v1/bookings/:id/reschedule", auth: "org-scoped", description: "Reschedule booking" },
            { method: "GET", path: "/api/v1/me/sessions", auth: "org-scoped", description: "Member sessions" },
            { method: "GET", path: "/api/v1/me/mentor_sessions", auth: "org-scoped", description: "Mentor sessions" },
            { method: "GET", path: "/api/v1/ai/context", auth: "none", description: "AI-readable system context" },
            { method: "GET", path: "/api/v1/ai/mcp/tools", auth: "org-scoped", description: "MCP tool definitions" },
            { method: "POST", path: "/api/v1/ai/mcp/call", auth: "org-scoped", description: "Execute MCP tool" }
          ]
        end

        def ai_feature_flags
          {
            ai_context_api: true,
            mcp_server: true,
            pre_session_briefs: "documented",
            mentor_semantic_matching: "documented",
            natural_language_booking: "documented"
          }
        end
      end
    end
  end
end
