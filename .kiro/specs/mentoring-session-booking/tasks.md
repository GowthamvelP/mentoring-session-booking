# Implementation Plan: Mentoring Session Booking

## Overview

A full-stack mentoring session booking system built with Rails 8 API-only + PostgreSQL 16 + Redis 7 + Sidekiq (backend) and React 18 + Vite + Tailwind CSS + TanStack Query (frontend). Tasks are ordered by dependency and priority for a 48-hour delivery window. Tier 1 tasks are required; Tier 2 (marked with `*`) are optional enhancements.

## Tasks

- [ ] 1. Project scaffold and infrastructure setup
  - [ ] 1.1 Create Rails 8 API-only application with PostgreSQL
    - Run `rails new backend --api --database=postgresql --skip-test` (use RSpec instead)
    - Configure `database.yml` for PostgreSQL with docker-compose service name
    - Add all required gems to Gemfile: `sidekiq`, `blueprinter`, `rack-attack`, `acts_as_tenant`, `strong_migrations`, `lograge`, `request_store`, `pagy`, `rack-cors`, `redis`, `dotenv-rails`
    - Add test gems: `rspec-rails`, `factory_bot_rails`, `shoulda-matchers`, `rantly`
    - Run `bundle install` and `rails generate rspec:install`
    - _Requirements: 15.1, 15.6, 19.6_

  - [ ] 1.2 Create React + Vite + Tailwind frontend scaffold
    - Initialize Vite React TypeScript project in `frontend/` directory
    - Install and configure Tailwind CSS
    - Install TanStack Query, React Router, axios
    - Configure Vite proxy or API base URL environment variable (`VITE_API_URL`)
    - Set up project structure: `src/api/`, `src/hooks/`, `src/components/`, `src/pages/`, `src/context/`, `src/lib/`
    - _Requirements: 15.6, 16.1_

  - [ ] 1.3 Create docker-compose.yml with all services
    - Define PostgreSQL 16, Redis 7, backend (Rails), sidekiq (same image), and frontend services
    - Configure health checks for PostgreSQL (`pg_isready`) and Redis (`redis-cli ping`)
    - Set `depends_on` with `condition: service_healthy` for backend and sidekiq
    - Configure backend command: `bin/rails db:prepare && bin/rails db:seed && bundle exec puma`
    - Configure sidekiq command: `bundle exec sidekiq -C config/sidekiq.yml`
    - Map ports: PostgreSQL 5432, Redis 6379, backend 3000, frontend 5173
    - Add named volumes for postgres_data and redis_data
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.6_

  - [ ] 1.4 Create backend Dockerfile and frontend Dockerfile
    - Backend: Ruby 3.3 base image, install gems, copy app, expose 3000
    - Frontend: Node 20 base image, install deps, build/serve via Vite, expose 5173
    - _Requirements: 15.1_

- [ ] 2. Database schema and migrations
  - [ ] 2.1 Enable pgcrypto extension and create organizations migration
    - Enable `pgcrypto` extension for UUID generation
    - Create organizations table: `id (uuid PK)`, `name (string, not null)`, `timezone (string, not null)`, timestamps
    - _Requirements: 19.1, 1.1_

  - [ ] 2.2 Create users migration with tenant scoping
    - Create users table: `id (uuid PK)`, `organization_id (uuid FK, not null)`, `email (string, not null)`, `name (string, not null)`, `role (string, not null)`, `password_digest (string)`, timestamps
    - Add unique composite index on `(organization_id, email)`
    - Add index on `organization_id`
    - Add foreign key constraint to organizations
    - _Requirements: 19.1, 19.2, 19.7_

  - [ ] 2.3 Create mentor_profiles migration
    - Create mentor_profiles table: `id (uuid PK)`, `user_id (uuid FK, not null)`, `bio (text, not null)`, `expertise (string array, not null)`, timestamps
    - Add unique index on `user_id`
    - Add foreign key constraint to users
    - _Requirements: 19.1, 19.2, 3.2_

  - [ ] 2.4 Create slots migration with composite constraints
    - Create slots table: `id (uuid PK)`, `mentor_id (uuid FK, not null)`, `organization_id (uuid FK, not null)`, `start_time (timestamp, not null)`, `end_time (timestamp, not null)`, `status (string, not null, default: 'available')`, timestamps
    - Add unique composite index on `(mentor_id, start_time)`
    - Add composite index on `(mentor_id, status, start_time)` for slot queries
    - Add index on `start_time`
    - Add foreign keys to users (mentor_id) and organizations
    - _Requirements: 19.1, 19.2, 19.5, 19.7_

  - [ ] 2.5 Create bookings migration with idempotency constraint
    - Create bookings table: `id (uuid PK)`, `slot_id (uuid FK, not null)`, `member_id (uuid FK, not null)`, `organization_id (uuid FK, not null)`, `status (string, not null, default: 'confirmed')`, `idempotency_key (string, not null)`, `booked_at (timestamp, not null)`, `cancelled_at (timestamp)`, timestamps
    - Add UNIQUE constraint on `idempotency_key`
    - Add indexes on `member_id`, `slot_id`, `idempotency_key`
    - Add foreign keys to slots, users (member_id), organizations
    - _Requirements: 19.1, 19.2, 19.4, 19.7, 6.4_

- [ ] 3. Core models with validations and associations
  - [ ] 3.1 Implement Organization, User, and MentorProfile models
    - Organization: `has_many :users`, validates name and timezone presence
    - User: `acts_as_tenant :organization`, `has_one :mentor_profile`, `has_many :slots (as mentor)`, `has_many :bookings (as member)`, enum role, validates email uniqueness scoped to org, `has_secure_password`
    - MentorProfile: `belongs_to :user`, validates bio and expertise presence
    - Add `User.mentors` scope
    - _Requirements: 1.2, 3.2, 3.3, 2.3_

  - [ ] 3.2 Implement Slot and Booking models
    - Slot: `acts_as_tenant :organization`, `belongs_to :mentor`, `has_one :booking`, enum status (available/booked), validates presence of start_time/end_time/status, `end_after_start` custom validation, scopes: `available`, `future`
    - Booking: `acts_as_tenant :organization`, `belongs_to :slot`, `belongs_to :member`, enum status (confirmed/cancelled/completed), validates idempotency_key presence/uniqueness, validates status/booked_at presence, scope: `active`
    - _Requirements: 5.1, 6.4, 7.1, 19.3, 19.4_

  - [ ]* 3.3 Write model unit tests with shoulda-matchers
    - Test all associations, validations, enums, and scopes for each model
    - Test custom validation `end_after_start` on Slot
    - Use factory_bot factories for test data
    - _Requirements: 19.1, 19.2, 19.4, 19.5_

- [ ] 4. Authentication stub and multi-tenancy
  - [ ] 4.1 Implement CurrentAttributes and Authenticatable concern
    - Create `Current` class with `user` and `organization` attributes using `ActiveSupport::CurrentAttributes`
    - Create `Authenticatable` controller concern: read `X-User-Id` and `X-Org-Id` headers, look up user and org, set `Current.user` and `Current.organization`, return 401 if missing/invalid
    - _Requirements: 2.1, 2.2, 1.3_

  - [ ] 4.2 Implement Tenantable concern with acts_as_tenant
    - Create `Tenantable` controller concern: call `ActsAsTenant.current_tenant = Current.organization`
    - Configure `acts_as_tenant` in models (already done in 3.1/3.2)
    - Ensure all queries are automatically scoped to current organization
    - _Requirements: 1.2, 1.5_

  - [ ] 4.3 Create Api::V1::BaseController with concerns and error handling
    - Inherit from `ActionController::API`
    - Include `Authenticatable` and `Tenantable` concerns
    - Add rescue_from handlers: `ActiveRecord::RecordNotFound` → 404, `ActiveRecord::RecordInvalid` → 422, `ActsAsTenant::Errors::NoTenantSet` → 401
    - Add `render_error` helper method for consistent error responses
    - _Requirements: 1.3, 20.4_

  - [ ] 4.4 Implement organizations and auth endpoints
    - `Api::V1::OrganizationsController#index` — list all organizations (no auth required)
    - `Api::V1::AuthController#select_org` — POST with org_id, set tenant context, return org details
    - Wire routes: `GET /api/v1/organizations`, `POST /api/v1/auth/select-org`
    - _Requirements: 1.1, 1.6, 2.1_

- [ ] 5. Seed script for development data
  - [ ] 5.1 Create comprehensive seed script
    - Create at least 2 organizations with different timezones
    - Create at least 4 mentors with profiles (bio, expertise arrays) across organizations
    - Create member users in each organization
    - Create at least 20 available slots spread across the next 7 days (various mentors, 1-hour durations, 15-min gaps)
    - Make seed script idempotent (use `find_or_create_by` or clear-and-reseed)
    - _Requirements: 15.5, 15.3_

- [ ] 6. Checkpoint — Database and models
  - Ensure all migrations run cleanly, models load, seed data populates. Ask the user if questions arise.

- [ ] 7. Core booking flow with pessimistic locking
  - [ ] 7.1 Implement BookingService with SELECT FOR UPDATE
    - Create `BookingService.call(slot_id:, member:, idempotency_key:)`
    - Check for existing booking with same idempotency_key first (return existing if found)
    - Wrap in `ActiveRecord::Base.transaction`: `Slot.lock.find(slot_id)`, validate status == available, update slot to booked, create Booking record with confirmed status
    - Return railway result: `{ success: true, booking: }` or `{ success: false, error:, status: }`
    - Invalidate Redis cache: `Rails.cache.delete_matched("slots:#{slot.mentor_id}:*")`
    - Enqueue `BookingConfirmationJob` after successful transaction
    - _Requirements: 5.1, 5.4, 5.6, 5.7, 5.8, 6.1, 6.2, 6.5_

  - [ ] 7.2 Implement CancellationService with 1-hour window
    - Create `CancellationService.call(booking:, user:)`
    - Verify requesting user owns the booking
    - Enforce 1-hour cancellation window (reject if slot start_time within 1 hour)
    - Wrap in transaction: update booking status to cancelled + set cancelled_at, update slot status back to available
    - Invalidate Redis cache for mentor's slots
    - Enqueue `BookingCancellationJob` after success
    - Return railway result pattern
    - _Requirements: 7.1, 7.2, 7.3, 7.5, 7.6, 7.7_

  - [ ] 7.3 Implement RescheduleService with atomic transaction
    - Create `RescheduleService.call(booking:, new_slot_id:, user:)`
    - Verify requesting user owns the booking
    - Wrap entire operation in single transaction: lock new slot (SELECT FOR UPDATE), validate new slot available, cancel original booking + restore original slot, book new slot + create new booking
    - If any step fails, entire transaction rolls back (original booking preserved)
    - Invalidate cache for both original and new mentor's slots (only on success)
    - Enqueue `BookingRescheduleJob` after success
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

  - [ ]* 7.4 Write property test for idempotency round-trip
    - **Property 1: Idempotency round-trip**
    - Submit same booking request multiple times with same idempotency_key, assert same booking returned and only 1 record created
    - **Validates: Requirements 6.5, 6.2**

  - [ ]* 7.5 Write property test for pessimistic lock prevents double-booking
    - **Property 2: Pessimistic lock prevents double-booking**
    - Spawn N concurrent threads booking same slot, assert exactly 1 succeeds
    - **Validates: Requirements 5.1, 5.8**

  - [ ]* 7.6 Write property test for cancellation restores slot availability
    - **Property 3: Cancellation restores slot availability**
    - Cancel a confirmed booking, assert slot returns to available and booking becomes cancelled
    - **Validates: Requirements 7.1, 7.2, 7.3**

  - [ ]* 7.7 Write property test for reschedule atomicity
    - **Property 4: Reschedule atomicity**
    - Attempt reschedule to unavailable slot, assert original booking unchanged
    - **Validates: Requirements 8.2, 8.4**

- [ ] 8. API controllers and serializers
  - [ ] 8.1 Create Blueprinter serializers for all resources
    - `OrganizationBlueprint`: id, name, timezone
    - `MentorBlueprint`: id, name, bio, expertise (from mentor_profile)
    - `SlotBlueprint`: id, start_time (ISO 8601 UTC), end_time (ISO 8601 UTC), status
    - `BookingBlueprint`: id, status, booked_at, cancelled_at, slot (nested start_time/end_time), mentor/member name and expertise
    - Never expose lock_version or internal tenant IDs
    - _Requirements: 20.1, 20.2, 20.3, 3.2, 4.5, 9.2, 10.2_

  - [ ] 8.2 Implement MentorsController and SlotsController
    - `MentorsController#index`: paginated list of mentors in current org using Pagy, serialize with MentorBlueprint
    - `SlotsController#index`: available slots for mentor within date range params, use `SlotService` with cache-aside pattern
    - Implement `SlotService.available_for_mentor(mentor_id:, start_date:, end_date:)` with Redis caching (TTL 300s)
    - Wire routes: `GET /api/v1/mentors`, `GET /api/v1/mentors/:mentor_id/slots`
    - _Requirements: 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5_

  - [ ] 8.3 Implement BookingsController (create, cancel, reschedule)
    - `#create`: require idempotency_key param, delegate to BookingService, return 201/200/409/422
    - `#cancel`: delegate to CancellationService, return 200/422
    - `#reschedule`: require new_slot_id, delegate to RescheduleService, return 201/422
    - Wire routes: `POST /api/v1/bookings`, `PATCH /api/v1/bookings/:id/cancel`, `POST /api/v1/bookings/:id/reschedule`
    - _Requirements: 5.1, 5.3, 6.1, 6.2, 6.3, 7.1, 7.6, 8.1, 8.4_

  - [ ] 8.4 Implement SessionsController (member and mentor views)
    - `#member_sessions`: GET /api/v1/me/sessions — all bookings for current user as member, ordered by slot start_time desc, paginated
    - `#mentor_sessions`: GET /api/v1/me/mentor_sessions — all bookings for slots owned by current user as mentor, ordered desc, paginated
    - Serialize with BookingBlueprint including mentor/member details
    - _Requirements: 9.1, 9.2, 9.3, 10.1, 10.2, 10.3_

  - [ ] 8.5 Configure routes with API versioning
    - Namespace all routes under `api/v1`
    - Include health endpoint outside auth (see task 14.1)
    - Ensure proper RESTful resource definitions
    - _Requirements: 1.1, 3.1, 4.1, 5.1_

- [ ] 9. Checkpoint — Backend API complete
  - Ensure all API endpoints respond correctly with seed data. Test booking, cancel, reschedule flows via curl or similar. Ask the user if questions arise.

- [ ] 10. Frontend implementation
  - [ ] 10.1 Set up API client and TanStack Query provider
    - Create axios instance with base URL from env, request/response interceptors
    - Add `X-User-Id` and `X-Org-Id` headers via interceptor (from context)
    - Configure TanStack QueryClient with sensible defaults (staleTime, retry)
    - Create OrgContext for selected organization state
    - _Requirements: 17.2, 16.1_

  - [ ] 10.2 Implement MentorsPage with mentor cards grid
    - Create `useMentors` hook with TanStack Query
    - Display mentor cards in responsive grid: name, bio excerpt, expertise tags
    - Implement mutually exclusive states: loading (skeleton), error (retry button), empty, content
    - Click mentor card navigates to slot selection page
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5_

  - [ ] 10.3 Implement MentorSlotsPage with weekly slot grid
    - Create `useSlots` hook (mentor_id, date range)
    - Display available slots grouped by date in a weekly grid with time buttons
    - On slot click: generate UUID idempotency_key, send booking mutation
    - Show optimistic "booking..." state while request in flight
    - On success: show success toast, redirect to My Sessions after 1-2s
    - On 409: show "slot taken" error, refresh slot listing
    - On 429: show rate limit error with retry-after duration
    - On other error: show error message, stay on page
    - _Requirements: 17.1, 17.2, 17.3, 17.4, 17.5, 17.6, 17.7_

  - [ ] 10.4 Implement MySessionsPage with cancel and reschedule
    - Create `useSessions` hook for member sessions
    - Display upcoming and past sessions in separate sections
    - Each session shows: mentor/member name, date, time, status
    - Cancel button: send cancel request, update list on server confirmation (not optimistic)
    - Reschedule button: navigate to mentor's slot grid for new selection
    - Disable action buttons and show loading indicator while action in progress
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5_

  - [ ] 10.5 Implement organization selection and routing
    - Create org selection page/modal on app load
    - Store selected org and user in context, pass as headers
    - Set up React Router: `/mentors`, `/mentors/:id/slots`, `/sessions`
    - Add navigation between pages
    - _Requirements: 1.1, 1.6_

- [ ] 11. Caching layer (Redis cache-aside)
  - [ ] 11.1 Configure Rails.cache with Redis and implement SlotService caching
    - Configure `config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }`
    - Implement cache-aside in SlotService: check cache key `slots:#{mentor_id}:#{start_date}:#{end_date}`, return cached if exists, else query + cache with 300s TTL
    - Implement cache invalidation in BookingService/CancellationService/RescheduleService using `Rails.cache.delete_matched("slots:#{mentor_id}:*")`
    - _Requirements: 4.3, 4.4, 5.6, 7.5, 8.6_

  - [ ]* 11.2 Write property test for cache consistency after mutation
    - **Property 7: Cache consistency after mutation**
    - After booking/cancel/reschedule, cached slot listing reflects the mutation
    - **Validates: Requirements 5.6, 7.5, 8.6**

- [ ] 12. Background jobs with Sidekiq
  - [ ] 12.1 Configure Sidekiq and implement job classes
    - Create `config/sidekiq.yml` with queue configuration
    - Configure Sidekiq to use Redis URL from environment
    - Implement `BookingConfirmationJob`: log confirmation event with booking details, `sidekiq_options retry: 3`
    - Implement `BookingCancellationJob`: log cancellation event with booking details, `sidekiq_options retry: 3`
    - Implement `BookingRescheduleJob`: log reschedule event with original and new slot details, `sidekiq_options retry: 3`
    - Ensure jobs are enqueued AFTER transaction commit in services
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 5.5_

- [ ] 13. Rate limiting and structured logging
  - [ ] 13.1 Configure Rack::Attack rate limiting with Redis
    - Install and configure `rack-attack` with Redis cache store
    - Throttle `POST /api/v1/bookings`: 10 req/min per user
    - Throttle `POST /api/v1/bookings/:id/reschedule`: 5 req/min per user
    - Throttle `GET /api/v1/mentors/:id/slots`: 100 req/min per user
    - Return HTTP 429 with `Retry-After` header on limit exceeded
    - Ensure middleware executes before controller logic
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

  - [ ] 13.2 Configure Lograge structured JSON logging with correlation IDs
    - Configure Lograge for JSON output in `config/environments/production.rb`
    - Use `request_store` gem for per-request correlation_id storage
    - Create middleware to generate unique correlation_id per request (use `X-Request-Id` header or generate UUID)
    - Include in all log entries: timestamp, level, message, correlation_id, user_id, org_id, request_path, request_method, response_status, duration_ms
    - Return correlation_id in `X-Request-Id` response header
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [ ] 14. Health check endpoint
  - [ ] 14.1 Implement HealthController with dependency checks
    - Create `Api::V1::HealthController#show` — no authentication required
    - Check PostgreSQL connectivity (ActiveRecord connection test)
    - Check Redis connectivity (ping)
    - Check Sidekiq connectivity (Sidekiq process info or Redis queue check)
    - Return 200 with `{ status: "ok", checks: {...} }` if all pass
    - Return 503 with `{ status: "degraded", checks: {...} }` if any fail, identifying failing component
    - Wire route: `GET /api/v1/health` (skip auth)
    - _Requirements: 13.1, 13.2, 13.3_

- [ ] 15. Checkpoint — Full backend with all features
  - Ensure all backend features work end-to-end: booking, cancel, reschedule, caching, rate limiting, health check. Ask the user if questions arise.

- [ ] 16. Testing and quality assurance
  - [ ]* 16.1 Write concurrency test for double-booking prevention
    - Spawn 5 threads all attempting to book the same slot simultaneously
    - Assert exactly 1 booking succeeds and others receive conflict/unavailable error
    - Assert slot has exactly 1 booking record
    - _Requirements: 5.1, 5.8_

  - [ ]* 16.2 Write tenant isolation property test
    - **Property 5: Tenant isolation**
    - Create data in org A, query in org B context, assert empty results
    - **Validates: Requirements 1.2, 1.5**

  - [ ]* 16.3 Write cancellation window property test
    - **Property 6: Cancellation window enforcement**
    - Attempt cancel at 59 minutes before slot, assert rejection
    - **Validates: Requirements 7.6**

  - [ ]* 16.4 Write booking transaction atomicity property test
    - **Property 8: Booking transaction atomicity**
    - Force failure mid-transaction, assert slot rolls back to available
    - **Validates: Requirements 5.7**

  - [ ]* 16.5 Write reschedule preserves booking count property test
    - **Property 9: Reschedule preserves booking count**
    - After successful reschedule, member's confirmed booking count unchanged
    - **Validates: Requirements 8.1**

  - [ ]* 16.6 Write request spec tests for API endpoints
    - Test all controller actions: correct status codes, response shapes, auth enforcement
    - Test error responses match `{ error:, details: }` format
    - Test pagination headers and metadata
    - _Requirements: 20.4, 3.1, 4.1, 5.1_

  - [ ]* 16.7 Write frontend component tests with Vitest
    - Test MentorCard, SlotGrid, SessionList components render correctly
    - Test mutually exclusive UI states (loading/error/empty/content)
    - Test TanStack Query hooks with MSW mocks
    - _Requirements: 16.5, 17.3_

- [ ] 17. Docker polish and README
  - [ ] 17.1 Finalize docker-compose, add .env.example, and create README
    - Add `.env.example` with all required environment variables
    - Ensure `docker-compose up` starts entire stack cleanly
    - Write README with: project overview, architecture summary, getting started (docker-compose up), API endpoints summary, tech stack rationale, design decisions (pessimistic locking, two-state slots, etc.)
    - Document Sidekiq Pro upgrade path for production
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_

- [ ] 18. Final checkpoint — Full system integration
  - Ensure docker-compose brings up entire system, frontend connects to backend, all booking flows work end-to-end. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional (Tier 2) and can be skipped for faster MVP delivery within the 48-hour window
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties from the design document
- The design uses pessimistic locking (SELECT FOR UPDATE) instead of optimistic locking — no lock_version column or retry loops needed
- Slots have only two states: `available` and `booked` (no cancelled slot status)
- Authentication is stubbed via `X-User-Id` and `X-Org-Id` headers — no real OAuth/SSO
- Cache invalidation uses pattern matching: `Rails.cache.delete_matched("slots:#{mentor_id}:*")`
- All Sidekiq jobs are enqueued after transaction commit to prevent phantom job references

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3", "1.4"] },
    { "id": 2, "tasks": ["2.1"] },
    { "id": 3, "tasks": ["2.2", "2.3"] },
    { "id": 4, "tasks": ["2.4", "2.5"] },
    { "id": 5, "tasks": ["3.1", "3.2"] },
    { "id": 6, "tasks": ["3.3", "4.1", "4.2"] },
    { "id": 7, "tasks": ["4.3"] },
    { "id": 8, "tasks": ["4.4", "5.1"] },
    { "id": 9, "tasks": ["7.1"] },
    { "id": 10, "tasks": ["7.2", "7.3"] },
    { "id": 11, "tasks": ["7.4", "7.5", "7.6", "7.7", "8.1"] },
    { "id": 12, "tasks": ["8.2", "8.3", "8.4", "8.5"] },
    { "id": 13, "tasks": ["11.1", "12.1", "13.1", "13.2", "14.1"] },
    { "id": 14, "tasks": ["11.2", "10.1"] },
    { "id": 15, "tasks": ["10.2", "10.5"] },
    { "id": 16, "tasks": ["10.3", "10.4"] },
    { "id": 17, "tasks": ["16.1", "16.2", "16.3", "16.4", "16.5", "16.6", "16.7"] },
    { "id": 18, "tasks": ["17.1"] }
  ]
}
```
