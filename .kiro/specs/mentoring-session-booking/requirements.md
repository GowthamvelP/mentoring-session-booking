# Requirements Document

## Introduction

A full-stack mentoring session booking system for TechMentor, enabling members within multi-tenant organizations to browse mentors, view available time slots, and book concurrency-safe mentoring sessions. The system uses Ruby on Rails 8.0 with PostgreSQL, Redis, and Sidekiq, deployed via docker-compose. It demonstrates production-grade patterns including optimistic locking, idempotent APIs, cache-aside caching, and multi-tenant data isolation.

## Glossary

- **Booking_System**: The Rails 8.0 backend application serving the API, managing data persistence, background jobs, and business logic.
- **Frontend**: The React 18 + Vite + Tailwind CSS single-page application consumed by Members and Mentors.
- **Organization**: A tenant entity representing a company or group. All data is scoped to an Organization.
- **Member**: A user with role `member` who books mentoring sessions with Mentors.
- **Mentor**: A user with role `mentor` who offers time slots for mentoring sessions.
- **Slot**: A time window offered by a Mentor for booking. Has statuses: `available`, `booked`, `cancelled`.
- **Booking**: A confirmed reservation of a Slot by a Member. Has statuses: `confirmed`, `cancelled`, `completed`.
- **Idempotency_Key**: A unique client-generated token sent with booking requests to prevent duplicate bookings on retry.
- **Lock_Version**: An integer column on the slots table used by ActiveRecord optimistic locking to detect concurrent modification (raises `ActiveRecord::StaleObjectError` on mismatch).
- **BookingService**: A service object encapsulating booking business logic including optimistic lock retry, idempotency check, cache invalidation, and job enqueue.
- **SlotService**: A service object responsible for slot query logic and cache management.
- **AvailableSlotsQuery**: A query object that retrieves available slots for a given mentor within a date range.
- **Sidekiq_Worker**: The Sidekiq process running background jobs (BookingConfirmationJob, BookingCancellationJob, BookingRescheduleJob).
- **Rails_Cache**: The Rails.cache interface backed by Redis, used for cache-aside slot listing caching.
- **Rack_Attack**: Rack middleware gem providing request throttling and rate limiting with Redis store.
- **Acts_As_Tenant**: Gem providing automatic tenant scoping on ActiveRecord queries via `set_current_tenant`.
- **Blueprinter_Serializer**: Blueprinter-based serializer classes defining the JSON API contract for each resource.
- **Health_Endpoint**: A public API endpoint reporting connectivity status of PostgreSQL, Redis, and Sidekiq.
- **Correlation_ID**: A unique request identifier propagated through logs and responses for distributed tracing.

## Requirements

### Requirement 1: Multi-Tenant Organization Context

**User Story:** As a Member or Mentor, I want to select my organization context, so that all data I see and create is scoped to my organization.

#### Acceptance Criteria

1. WHEN a user sends a POST request to `/api/v1/auth/select-org` with a valid organization ID, THE Booking_System SHALL set the tenant context for the session and return the organization details.
2. WHILE a tenant context is active, THE Booking_System SHALL scope all ActiveRecord queries to the current organization using Acts_As_Tenant.
3. IF a request is made without a valid tenant context, THEN THE Booking_System SHALL return HTTP 401 with an error message indicating missing organization context.
4. IF a tenant context becomes invalid during an active session (e.g., organization deleted or deactivated), THEN THE Booking_System SHALL return HTTP 401 on subsequent requests.
5. THE Booking_System SHALL enforce tenant isolation at the database query level such that no query returns data belonging to a different organization.
6. WHEN a GET request is sent to `/api/v1/organizations`, THE Booking_System SHALL return all available organizations for selection.

### Requirement 2: Stub Authentication

**User Story:** As a developer evaluating this system, I want authentication to be stubbed, so that I can test all flows without implementing OAuth or SSO.

#### Acceptance Criteria

1. THE Booking_System SHALL provide a stub authentication mechanism that accepts a user identifier and organization to establish session context without real credential verification.
2. WHEN a stub auth session is established, THE Booking_System SHALL set `Current.user` and `Current.organization` for the duration of the request using Rails' `CurrentAttributes`.
3. THE Booking_System SHALL use the Rails 8 authentication generator scaffold as the foundation for the stub auth flow.
4. WHEN a user authenticates with credentials matching their current active session, THE Booking_System SHALL accept the request and refresh the session context.

### Requirement 3: Browse Mentors

**User Story:** As a Member, I want to browse available mentors in my organization, so that I can find a suitable mentor to book a session with.

#### Acceptance Criteria

1. WHEN a GET request is sent to `/api/v1/mentors`, THE Booking_System SHALL return a paginated list of mentors within the current organization using Pagy.
2. THE Blueprinter_Serializer SHALL include each mentor's name, bio, and expertise array in the response.
3. WHILE the tenant context is active, THE Booking_System SHALL return only mentors belonging to the current organization.
4. IF the tenant scoping mechanism fails while a valid tenant context is active, THEN THE Booking_System SHALL return HTTP 500 with an error message (not an empty list).

### Requirement 4: View Available Slots

**User Story:** As a Member, I want to view a mentor's available time slots, so that I can choose a convenient time for a session.

#### Acceptance Criteria

1. WHEN a GET request is sent to `/api/v1/mentors/:id/slots`, THE Booking_System SHALL return available slots for the specified mentor within the requested date range.
2. THE AvailableSlotsQuery SHALL filter slots to return only those with status `available` and `start_time` in the future.
3. WHEN a cached result exists in Rails_Cache for the key `slots:#{mentor_id}:#{start_date}:#{end_date}`, THE Booking_System SHALL return the cached result without querying the database.
4. WHEN no cached result exists, THE Booking_System SHALL query the database, cache the result with a TTL of 300 seconds, and return the response.
5. THE Blueprinter_Serializer SHALL include slot ID, start_time, end_time, and status in UTC format.

### Requirement 5: Book a Slot (Concurrency-Safe)

**User Story:** As a Member, I want to book an available slot with a mentor, so that I can secure a mentoring session without risk of double-booking.

#### Acceptance Criteria

1. WHEN a POST request is sent to `/api/v1/bookings` with a valid slot_id and idempotency_key, THE BookingService SHALL attempt to transition the slot status from `available` to `booked` using optimistic locking.
2. IF ActiveRecord raises `StaleObjectError` during the slot update, THEN THE BookingService SHALL retry the operation up to 3 times with exponential backoff (200ms, 400ms, 800ms).
3. IF all 3 retries are exhausted, THEN THE Booking_System SHALL return HTTP 409 with an error indicating the slot is no longer available.
4. WHEN the slot is successfully transitioned to `booked`, THE BookingService SHALL create a Booking record with status `confirmed` and the provided idempotency_key.
5. WHEN a booking is successfully created, THE BookingService SHALL enqueue a BookingConfirmationJob to Sidekiq_Worker.
6. WHEN a booking is successfully created, THE BookingService SHALL invalidate the Rails_Cache entries matching `slots:#{mentor_id}:*`.
7. THE Booking_System SHALL wrap the slot update and booking creation in a single ActiveRecord transaction to ensure atomicity.
8. WHEN the slot status is not `available` at the time of booking attempt, THE Booking_System SHALL return HTTP 422 with an error indicating the slot cannot be booked.

### Requirement 6: Idempotent Booking API

**User Story:** As a client application, I want booking requests to be idempotent, so that network retries never create duplicate bookings.

#### Acceptance Criteria

1. THE Booking_System SHALL require an `idempotency_key` header or parameter on all POST `/api/v1/bookings` requests.
2. WHEN a booking request is received with an idempotency_key that already exists in the bookings table, THE Booking_System SHALL return HTTP 200 with the existing booking (not HTTP 201).
3. IF a booking request is received without an idempotency_key, THEN THE Booking_System SHALL return HTTP 422 with a validation error.
4. THE bookings table SHALL enforce uniqueness on the idempotency_key column via a database-level UNIQUE constraint.
5. FOR ALL valid booking payloads, submitting the same request with the same idempotency_key multiple times SHALL produce the same response and SHALL NOT create additional bookings (idempotency round-trip property).

### Requirement 7: Cancel Booking

**User Story:** As a Member, I want to cancel a confirmed booking, so that the slot becomes available for other members.

#### Acceptance Criteria

1. WHEN a PATCH request is sent to `/api/v1/bookings/:id/cancel`, THE BookingService SHALL transition the booking status from `confirmed` to `cancelled` and set `cancelled_at` to the current timestamp.
2. WHEN a booking is cancelled, THE BookingService SHALL transition the associated slot status from `booked` back to `available`.
3. THE BookingService SHALL wrap both the booking status transition and slot status transition in a single ActiveRecord transaction; IF either operation fails, THEN both SHALL be rolled back.
4. WHEN a booking is cancelled, THE BookingService SHALL enqueue a BookingCancellationJob to Sidekiq_Worker.
5. WHEN a booking is cancelled, THE BookingService SHALL invalidate the Rails_Cache entries matching `slots:#{mentor_id}:*`.
6. IF a cancellation is requested for a booking that is not in `confirmed` status, THEN THE Booking_System SHALL return HTTP 422 with an error indicating the booking cannot be cancelled.
7. THE Booking_System SHALL verify the requesting user is the member who owns the booking before allowing cancellation.

### Requirement 8: Reschedule Booking

**User Story:** As a Member, I want to reschedule a confirmed booking to a different slot, so that I can change the session time without losing my reservation.

#### Acceptance Criteria

1. WHEN a POST request is sent to `/api/v1/bookings/:id/reschedule` with a new_slot_id, THE BookingService SHALL cancel the existing booking and create a new booking for the target slot in a single transaction.
2. IF any step within the reschedule transaction fails (including new booking creation after original cancellation), THEN THE entire transaction SHALL be rolled back, preserving the original booking in its original state.
3. THE BookingService SHALL apply optimistic locking on the new slot with the same retry strategy as a new booking (3 retries, exponential backoff).
4. IF the new slot is not available, THEN THE Booking_System SHALL return HTTP 422 and SHALL NOT cancel the original booking (transactional atomicity).
5. WHEN a reschedule succeeds, THE BookingService SHALL enqueue a BookingRescheduleJob to Sidekiq_Worker.
6. WHEN a reschedule succeeds, THE BookingService SHALL invalidate Rails_Cache entries for both the original and new mentor's slot caches. THE BookingService SHALL only invalidate Rails_Cache entries when the reschedule transaction completes successfully; failed reschedules SHALL NOT trigger cache invalidation.
7. THE Booking_System SHALL verify the requesting user owns the original booking before allowing reschedule.

### Requirement 9: My Sessions View (Member Perspective)

**User Story:** As a Member, I want to see all my booked sessions, so that I can track upcoming and past mentoring sessions.

#### Acceptance Criteria

1. WHEN a GET request is sent to `/api/v1/me/sessions`, THE Booking_System SHALL return all bookings for the current user as a member, ordered by slot start_time descending.
2. THE Blueprinter_Serializer SHALL include booking ID, status, slot start_time, slot end_time, mentor name, and mentor expertise in the response.
3. THE Booking_System SHALL paginate results using Pagy.

### Requirement 10: My Sessions View (Mentor Perspective)

**User Story:** As a Mentor, I want to see all sessions booked with me, so that I can prepare for upcoming mentoring sessions.

#### Acceptance Criteria

1. WHEN a GET request is sent to `/api/v1/me/mentor_sessions`, THE Booking_System SHALL return all bookings for slots owned by the current user as a mentor, ordered by slot start_time descending.
2. THE Blueprinter_Serializer SHALL include booking ID, status, slot start_time, slot end_time, member name, and booked_at timestamp in the response.
3. THE Booking_System SHALL paginate results using Pagy.

### Requirement 11: Rate Limiting

**User Story:** As a platform operator, I want API rate limiting, so that the system is protected from abuse and resource exhaustion.

#### Acceptance Criteria

1. THE Rack_Attack middleware SHALL throttle POST `/api/v1/bookings` to a maximum of 10 requests per minute per user.
2. THE Rack_Attack middleware SHALL throttle POST `/api/v1/bookings/:id/reschedule` to a maximum of 5 requests per minute per user.
3. THE Rack_Attack middleware SHALL throttle GET `/api/v1/mentors/:id/slots` to a maximum of 100 requests per minute per user.
4. WHEN a rate limit is exceeded, THE Booking_System SHALL return HTTP 429 with a `Retry-After` header indicating when the client may retry.
5. THE Rack_Attack middleware SHALL use Redis as the cache store for distributed rate limit state.
6. THE Rack_Attack middleware SHALL execute BEFORE controller logic, ensuring rate limit checks precede any business logic execution.

### Requirement 12: Background Job Processing

**User Story:** As a platform operator, I want booking lifecycle events processed asynchronously, so that API response times remain under 100ms regardless of downstream processing.

#### Acceptance Criteria

1. WHEN a booking is confirmed, THE Sidekiq_Worker SHALL process the BookingConfirmationJob and log the confirmation event with booking details.
2. WHEN a booking is cancelled, THE Sidekiq_Worker SHALL process the BookingCancellationJob and log the cancellation event with booking details.
3. WHEN a booking is rescheduled, THE Sidekiq_Worker SHALL process the BookingRescheduleJob and log the reschedule event with original and new slot details.
4. IF a Sidekiq job fails, THEN THE Sidekiq_Worker SHALL retry up to 3 times with exponential backoff as configured by `sidekiq_options retry: 3`.
5. IF all retries are exhausted, THEN THE Sidekiq_Worker SHALL move the job to the dead letter queue for manual investigation.

### Requirement 13: Health Check Endpoint

**User Story:** As a platform operator, I want a health check endpoint, so that container orchestration and monitoring tools can verify system readiness.

#### Acceptance Criteria

1. WHEN a GET request is sent to `/api/v1/health`, THE Health_Endpoint SHALL check connectivity to PostgreSQL, Redis, and Sidekiq.
2. WHEN all checks (PostgreSQL, Redis, and Sidekiq) pass, THE Health_Endpoint SHALL return HTTP 200 with status `ok` and individual check results. IF any single check fails, THEN THE Health_Endpoint SHALL return HTTP 503 with status `degraded` and identify the failing component.
3. THE Health_Endpoint SHALL be accessible without authentication under normal conditions. IF the authentication system itself is down, THE Health_Endpoint SHALL still respond (bypassing auth).

### Requirement 14: Structured Logging and Observability

**User Story:** As a platform operator, I want structured JSON logs with correlation IDs, so that I can trace requests across services and debug production issues.

#### Acceptance Criteria

1. THE Booking_System SHALL output all request logs in structured JSON format using Lograge.
2. THE Booking_System SHALL generate a unique Correlation_ID for each incoming request and include it in all log entries for that request using RequestStore.
3. THE Booking_System SHALL include the following fields in each log entry: timestamp, level, message, correlation_id, user_id, org_id, request_path, request_method, response_status, duration_ms.
4. THE Booking_System SHALL return the Correlation_ID in the `X-Request-Id` response header.

### Requirement 15: Docker Compose Deployment

**User Story:** As a developer evaluating this system, I want to run the entire application with a single `docker-compose up` command, so that I can evaluate the system without manual setup.

#### Acceptance Criteria

1. WHEN `docker-compose up` is executed, THE Booking_System SHALL start PostgreSQL, Redis, the Rails backend, the Sidekiq worker, and the React frontend.
2. THE Booking_System SHALL wait for PostgreSQL and Redis health checks to pass before starting the Rails backend.
3. WHEN the Rails backend starts, THE Booking_System SHALL run `bin/rails db:prepare` to create and migrate the database, then `bin/rails db:seed` to populate sample data.
4. IF `bin/rails db:prepare` fails, THEN THE Booking_System SHALL NOT proceed to seeding and SHALL exit with a non-zero exit code.
5. THE seed script SHALL create at least 2 organizations, 4 mentors with profiles, and 20 available slots spread across the next 7 days.
6. THE Frontend SHALL be accessible at `http://localhost:5173` and the API at `http://localhost:3000/api/v1`.

### Requirement 16: Frontend — Mentor Browsing

**User Story:** As a Member, I want to browse mentor cards in the UI, so that I can select a mentor based on their name, bio, and expertise.

#### Acceptance Criteria

1. WHEN the Member navigates to the mentors page, THE Frontend SHALL display a grid of mentor cards showing name, bio excerpt, and expertise tags.
2. WHILE the mentor list is loading, THE Frontend SHALL display a skeleton loading state.
3. WHEN the mentor list is empty, THE Frontend SHALL display an empty state message indicating no mentors are available.
4. IF the API request fails, THEN THE Frontend SHALL display an error state with a retry action.
5. THE Frontend SHALL enforce mutually exclusive UI states: exactly one of loading, error, empty, or content SHALL be displayed at any given time.

### Requirement 17: Frontend — Slot Selection and Booking

**User Story:** As a Member, I want to view a mentor's available slots in a weekly grid and book with one click, so that the booking experience is fast and intuitive.

#### Acceptance Criteria

1. WHEN the Member selects a mentor, THE Frontend SHALL display available slots in a weekly grid grouped by date with time slot buttons.
2. WHEN the Member clicks an available slot button, THE Frontend SHALL send a booking request with a client-generated idempotency_key using TanStack Query mutation.
3. WHILE the booking request is in flight, THE Frontend SHALL show an optimistic "booking..." state on the clicked slot using TanStack Query optimistic updates.
4. WHEN the booking succeeds, THE Frontend SHALL display a success toast notification, wait 1-2 seconds, then redirect to the My Sessions page.
5. IF the booking fails with HTTP 409, THEN THE Frontend SHALL display an error indicating the slot was taken, remain on the current slot selection page, and refresh the slot listing.
6. IF the booking fails with HTTP 429, THEN THE Frontend SHALL display a rate limit error with the retry-after duration and remain on the current slot selection page.
7. IF the booking fails with any other error, THEN THE Frontend SHALL display an error message and remain on the current slot selection page (not redirect to My Sessions).

### Requirement 18: Frontend — My Sessions Management

**User Story:** As a Member or Mentor, I want to view and manage my sessions, so that I can cancel or reschedule upcoming sessions.

#### Acceptance Criteria

1. WHEN the Member navigates to "My Sessions", THE Frontend SHALL display upcoming and past sessions in separate sections.
2. THE Frontend SHALL display each session with the mentor/member name, date, time, and status.
3. WHEN the Member clicks "Cancel" on a confirmed session, THE Frontend SHALL send a cancellation request and update the session list only after the server returns a successful cancellation response (server-confirmed update, not optimistic).
4. WHEN the Member clicks "Reschedule" on a confirmed session, THE Frontend SHALL navigate to the mentor's slot grid for new slot selection.
5. WHILE any management action is in progress, THE Frontend SHALL disable the action button and show a loading indicator.

### Requirement 19: Data Model and Migrations

**User Story:** As a developer, I want a well-structured database schema with safe migrations, so that the data layer supports all business operations with integrity constraints.

#### Acceptance Criteria

1. THE Booking_System SHALL use UUID primary keys for all tables using the `pgcrypto` PostgreSQL extension.
2. THE Booking_System SHALL enforce referential integrity via foreign key constraints on all relationship columns.
3. THE slots table SHALL include a `lock_version` column (integer, default 0) for ActiveRecord optimistic locking.
4. THE bookings table SHALL enforce a UNIQUE constraint on `idempotency_key` at the database level.
5. THE slots table SHALL enforce a UNIQUE constraint on `(mentor_id, start_time)` to prevent overlapping slots. THE Booking_System SHALL enforce slot uniqueness via this database constraint only; buffer_minutes between consecutive slots is enforced at seed-script generation time, not at runtime.
6. THE Booking_System SHALL validate all migrations with the strong_migrations gem to prevent unsafe operations.
7. THE Booking_System SHALL create indexes on all foreign key columns and frequently queried columns (slots.start_time, bookings.idempotency_key).

### Requirement 20: API Serialization Contract

**User Story:** As a frontend developer, I want a consistent and explicit API contract, so that I can reliably consume API responses without worrying about schema changes.

#### Acceptance Criteria

1. THE Booking_System SHALL use Blueprinter_Serializer classes to define all API response shapes.
2. THE Blueprinter_Serializer SHALL never expose internal database fields (lock_version, internal IDs of related tenants) in API responses.
3. THE Booking_System SHALL return all timestamps in ISO 8601 UTC format.
4. THE Booking_System SHALL return consistent error responses with `{ error: String, details: Object }` structure for all 4xx and 5xx responses.
