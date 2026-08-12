# Backend — Rails 8 API

Ruby on Rails 8.1.3 API-only application serving the mentoring session booking API.

## Setup

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
```

## Run

```bash
# API server
bundle exec puma -C config/puma.rb

# Background jobs (separate terminal)
bundle exec sidekiq

# View sent emails (development only)
# Navigate to http://localhost:3000/letter_opener
```

## Test

```bash
bundle exec rspec                    # Full suite (212 specs, 92.75% coverage)
bundle exec rspec --tag concurrency  # Just concurrency tests
bundle exec brakeman                 # Security scan
bundle exec bundler-audit check      # Dependency audit
bundle exec rubocop                  # Linting (0 offenses)
```

## Key Architecture

- **Controllers**: `app/controllers/api/v1/` — Thin API controllers (bookings, mentors, slots, notifications, AI)
- **Services**: `app/services/` — BookingService, CancellationService, RescheduleService, SlotService, NotificationService
- **Models**: `app/models/` — Organization, User, MentorProfile, Slot, Booking, Notification, PreSessionBrief
- **Serializers**: `app/serializers/` — Blueprinter-based API contracts
- **Jobs**: `app/jobs/` — Sidekiq jobs (BookingConfirmationJob, BookingCancellationJob, BookingRescheduleJob, BookingBriefJob)
- **Mailers**: `app/mailers/` — BookingMailer (confirmation, cancellation, reschedule emails)
- **Middleware**: `app/middleware/` — CorrelationIdMiddleware
- **AI**: `app/controllers/api/v1/ai/` — ContextController (system metadata) + McpController (MCP Server)

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/organizations` | List organizations |
| POST | `/api/v1/auth/select-org` | Establish session context |
| GET | `/api/v1/health` | Health check (PG, Redis, Sidekiq) |
| GET | `/api/v1/mentors` | Browse/search mentors (GIN trigram) |
| GET | `/api/v1/mentors/:id/slots` | Available slots (cached, 300s TTL) |
| POST | `/api/v1/bookings` | Book a slot (idempotent, buffer-validated) |
| PATCH | `/api/v1/bookings/:id/cancel` | Cancel booking (with reason) |
| POST | `/api/v1/bookings/:id/reschedule` | Reschedule (atomic swap) |
| GET | `/api/v1/me/sessions` | Member sessions |
| GET | `/api/v1/me/mentor_sessions` | Mentor sessions |
| GET | `/api/v1/notifications` | Notifications + unread count |
| PATCH | `/api/v1/notifications/:id/mark_read` | Mark notification read |
| POST | `/api/v1/notifications/mark_all_read` | Mark all read |
| GET | `/api/v1/ai/context` | AI-readable system context |
| GET | `/api/v1/ai/mcp/tools` | MCP tool definitions |
| POST | `/api/v1/ai/mcp/call` | Execute MCP tool |

## Email Notifications

Emails are delivered asynchronously via Sidekiq + ActionMailer:
- **Development**: Captured by `letter_opener_web` — view at http://localhost:3000/letter_opener
- **Production**: SMTP delivery via environment variables (SendGrid/Mailgun/SES)

Both member and mentor receive emails for: booking confirmation, cancellation, and reschedule events.

## Sidekiq Queues

| Queue | Weight | Purpose |
|-------|--------|---------|
| critical | 6 | Booking emails (user-facing, time-sensitive) |
| default | 3 | Standard background processing |
| notifications | 2 | Push notifications (future) |
| ai | 1 | AI brief generation, embeddings |
| low | 1 | Analytics, cleanup |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| DATABASE_URL | PostgreSQL connection | postgresql://mentoring:mentoring@localhost:5432/mentoring_development |
| REDIS_URL | Redis for cache + Sidekiq | redis://localhost:6379/0 |
| SECRET_KEY_BASE | Rails secret key | (generated) |
| RAILS_ENV | Environment | development |
| OPENAI_API_KEY | OpenAI key for AI features | (optional — stub mode when absent) |
| SMTP_ADDRESS | SMTP server (production) | (optional) |
| SMTP_PORT | SMTP port | 587 |
| SMTP_USERNAME | SMTP user | (optional) |
| SMTP_PASSWORD | SMTP password | (optional) |

## Database

- **PostgreSQL 16** with UUID primary keys, pg_trgm extension
- **15 migrations** (pgcrypto, organizations, users, mentor_profiles, slots, bookings, indexes, notifications, pre_session_briefs)
- **GIN indexes**: trigram on users.name, array on mentor_profiles.expertise, composite on bookings
- Seeds: 2 orgs, 4 mentors, 4 members, 40+ slots (idempotent, 30-day window)
