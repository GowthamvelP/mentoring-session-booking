# KIRO SPEC MODE PROMPT — MENTORING SYSTEM DESIGN EXERCISE
## System Design Exercise | Mentoring Session Booking System
## Candidate: Gowthamvel Palanivel
## Date: 2026-08-11
## Budget: ~1000 Kiro credits, $20 AI tool budget

---

# KIRO INSTRUCTIONS
- Read this file section by section as requested
- Do NOT generate code until we reach Plan Mode
- Challenge my assumptions — don't agree by default
- When you disagree, provide concrete alternatives with tradeoffs

## WHO I AM

I'm a Technical Lead / Backend & Platform Architect with 9+ years of experience.
Currently at Nextpoint, building document processing pipelines at scale 
(30M+ docs/month).

I built GetGist (cal.id/gowthamvel-palanivel), a Calendly-like scheduling 
platform where users set availability and end-users book slots with 
calendar conflict detection. I know this domain deeply:
- Availability rules (weekdays, weekends, overrides)
- Calendar integration (Google/Outlook/Apple)
- Conflict detection across multiple calendars
- Slot state machines and booking transactions
- Idempotency and concurrency patterns

I must resist scope creep from that experience. This is a thin vertical 
slice, not a full product.

---

## THE EXERCISE

Build a full-stack mentoring session booking app for TechMentor 
(mentoring platform, competitors: enterprise competitors).

Working app via docker-compose. README. Technical walkthrough.

Key constraint: AI usage is expected and evaluated — how I drive and 
correct AI, not whether I use it.

---

## MY PROPOSED STACK — EXPLORATION PHASE

I'm leaning toward Node.js + Express + Prisma + PostgreSQL backend and 
React 18 + Vite + Tailwind frontend. But I'm not certain. Here's my 
thinking and where I need your genuine input.

### Backend Dilemma: Node.js vs. Python vs. Rails

| Factor | Node.js/Express | Python/FastAPI | Ruby on Rails |
|--------|----------------|--------------|---------------|
| My fluency | Daily | Side projects | Used 2 years ago |
| 48h speed | Fastest | Medium (refresh needed) | Slow (relearn) |
| Async/queue | Native (Bull) | Good (asyncpg) | Good (Sidekiq) |
| Type safety | Prisma | Pydantic (excellent) | ActiveRecord |
| TechMentor alignment | None | None | ✅ Their stack |
| Concurrency primitives | Raw SQL/Prisma | SQLAlchemy raw | ActiveRecord pessimistic |

**My bias:** Node.js — daily fluency, Prisma's migration tooling, fast boot.

**My doubt:** TechMentor uses Rails. Convention-over-configuration might 
save me 2-4 hours of boilerplate. ActiveRecord's `lock_version` is 
native optimistic locking.

**Kiro, I need you to:**
1. Model the Rails implementation of optimistic booking with 
   `lock_version` and `with_lock`
2. Compare boilerplate: Rails controllers vs. Express middleware for 
   auth stub + tenancy injection
3. Estimate ramp-up time for someone who used Rails 2 years ago but 
   hasn't touched ActiveRecord locking
4. If Rails saves me &gt;3 hours net, make the case. Otherwise, I'll 
   proceed with Node.js and document Rails onboarding.

### Frontend Dilemma: React/Vite vs. Next.js

| Factor | React + Vite | Next.js App Router |
|--------|-------------|-------------------|
| SSR need | None (internal dashboard) | Unnecessary |
| Setup | `npm create vite@latest` | Routing conventions, RSC boundaries |
| API integration | TanStack Query (standard) | `unstable_cache`, `revalidatePath` |
| Optimistic UI | TanStack Query native | Complex with Server Components |
| 48h speed | Immediate | 1-2h understanding RSC quirks |

**My bias:** Vite — zero config, no SSR boundary confusion.

**My doubt:** Next.js Server Components could eliminate the slot grid 
API call. `unstable_cache` for slot listings.

**Kiro, I need you to:**
1. Show me the Server Component implementation of the mentor detail page 
   with slot grid
2. Model cache invalidation: when a booking happens, how does the Server 
   Component cache get invalidated?
3. Compare to TanStack Query's optimistic UI + cache invalidation
4. If Server Components simplify without adding cache invalidation 
   complexity, make the case. Otherwise, I'll stick with Vite.

### Cache/Queue Dilemma: Redis+Bull vs. Alternatives

| Factor | Redis + Bull | RabbitMQ | In-Memory |
|--------|-------------|----------|-------------|
| Infrastructure | Single Redis instance | Separate service | None |
| Retry logic | Built-in | Manual | None |
| Persistence | Redis AOF/RDB | Disk | Lost on restart |
| Monitoring | Bull dashboard | Management UI | None |
| 48h complexity | Low | Medium | Deceptively simple |

**My bias:** Redis+Bull — single infra component, built-in retry.

**Kiro, challenge this:** When would RabbitMQ's routing topology be 
worth the separate infrastructure? When would in-memory queue be 
acceptable for an MVP?

---

## FINAL STACK DECISION (Post-Analysis)

> **This section supersedes the "EXPLORATION PHASE" above.**
> The exploration is preserved for README documentation of AI-assisted decision-making.

### Backend: Ruby on Rails 8.0 + PostgreSQL + Redis + Sidekiq

**Decision rationale (scored against framework):**

| Criteria | Weight | Rails Score | Why |
|----------|--------|-------------|-----|
| 48-hour delivery confidence | 40% | 5/5 | Daily Rails user (Nextpoint monolith), built Calendly-class scheduling platform in Rails, Sidekiq migration expert |
| Production correctness | 30% | 5/5 | Native `lock_version` optimistic locking, `Current.organization` tenancy, Sidekiq for jobs, `Rails.cache` for caching |
| Team alignment (TechMentor) | 20% | 5/5 | TechMentor core product is Rails; signals immediate team contribution |
| Learning value | 10% | 3/5 | Demonstrates depth over breadth |
| **Weighted Total** | | **4.8/5** | |

**Rails 8.0 advantages leveraged:**
- **Solid Queue** available (but using Sidekiq free for richer monitoring + familiar API)
- **Solid Cache** available (but using Redis for unified cache+queue infra in docker-compose)
- **Authentication generator** — `rails generate authentication` gives session-based auth scaffold (simplifies stub auth)
- **Thruster** proxy in Dockerfile — asset caching and compression out of the box
- **Propshaft** — lightweight asset pipeline (no Sprockets overhead)
- **FOR UPDATE SKIP LOCKED** — native PostgreSQL support for queue polling (Solid Queue uses this)
- **Regexp.timeout = 1s default** — security hardening against ReDoS attacks

**Why NOT Sidekiq Pro/Enterprise (free tier suffices for MVP):**
- Free Sidekiq provides: reliable enqueue, retry with exponential backoff, dead letter queue, concurrency control
- Pro adds: batches, unique jobs, rate limiting (we implement rate limiting at rack level instead)
- Enterprise adds: periodic jobs, rolling restarts, multi-redis (not needed at this scale)
- **Document in README:** "Sidekiq Pro would add native unique jobs (replacing our idempotency_key approach) and batch operations for bulk notifications"

### Frontend: React 18 + Vite + Tailwind CSS + TanStack Query

**Unchanged from exploration.** Vite remains the right choice — no SSR needed.

### Infrastructure: PostgreSQL + Redis + Sidekiq (docker-compose)

**Architecture:**
- PostgreSQL: Primary data store + migrations (via ActiveRecord + strong_migrations)
- Redis: Cache store (Rails.cache) + Sidekiq job queue (single instance, dual purpose)
- Sidekiq: Background job processing (booking confirmations, cancellations, notifications)

---

### Gem Strategy — Maximise Community Solutions, Minimise Custom Code

| Concern | Gem | Why this gem |
|---------|-----|-------------|
| **API Serialization** | `blueprinter` | Fast, declarative, no magic. Explicit field definitions prevent accidental data leaks |
| **Background Jobs** | `sidekiq` (free) | Battle-tested, Redis-backed, built-in retry + dead letters. You know it deeply |
| **Rate Limiting** | `rack-attack` | Rack middleware = framework-agnostic, Redis store for distributed state |
| **Caching** | `Rails.cache` + `redis` gem | Native Rails cache-aside with Redis backend, `expires_in`, pattern-based invalidation |
| **Multi-tenancy** | `acts_as_tenant` | Automatic scoping via `set_current_tenant`, prevents cross-tenant data leaks at query level |
| **Safe Migrations** | `strong_migrations` | Catches unsafe migrations in dev (lock timeouts, non-concurrent index creation, column removal without ignoring) |
| **Structured Logging** | `lograge` + `request_store` | JSON structured logs with correlation IDs; `request_store` for per-request context |
| **Pagination** | `pagy` | Fastest Ruby pagination gem, minimal memory footprint vs. kaminari/will_paginate |
| **Testing** | `rspec-rails` + `factory_bot_rails` + `shoulda-matchers` | Standard Rails testing stack |
| **Concurrency Testing** | `parallel_tests` or custom threads | For simulating concurrent booking attempts |
| **API Documentation** | `rswag` (if time permits) | Swagger/OpenAPI from RSpec request specs |
| **CORS** | `rack-cors` | Standard cross-origin handling for SPA frontend |
| **UUID Primary Keys** | `pgcrypto` extension | Native PostgreSQL UUID generation, no gem needed |
| **HTTP Client** | `faraday` (if needed) | Standard Ruby HTTP client with middleware stack |
| **Environment Config** | `dotenv-rails` | Development environment variables |
| **Code Quality** | `rubocop-rails` + `brakeman` | Linting + security static analysis |

---

### Rails Architecture & Design Patterns

**Project structure (Rails conventions + service layer):**
```
app/
├── controllers/
│   └── api/v1/          # Versioned API controllers (thin)
├── models/              # AR models (validations, associations, scopes — NO business logic)
├── services/            # Service classes (BookingService, SlotService, etc.)
├── policies/            # Authorization logic (even with stub auth)
├── serializers/         # Blueprinter serializers (explicit, no magic)
├── jobs/                # Sidekiq jobs (BookingConfirmationJob, etc.)
├── concerns/            # Shared model/controller concerns (Tenantable, Idempotent)
├── errors/              # Custom error classes (OptimisticLockConflict, TenantViolation)
└── validators/          # Custom validators (IdempotencyKeyValidator)
```

**Design patterns to apply:**
- **Service Objects** — All business logic in `app/services/`. Controllers call services, services call models.
- **Concerns for cross-cutting** — `Tenantable` (model concern for default_scope), `Authenticatable` (controller concern)
- **Decorator/Presenter via Blueprinter** — API responses shaped by serializers, not models. Comment: "Serializers define the API contract. Never expose raw AR objects. Add new views (`:detailed`, `:minimal`) as needed."
- **Command Pattern for bookings** — `BookingService.call(slot_id:, member:, idempotency_key:)` returns Result object
- **Railway-oriented results** — Service returns `{ success: true, booking: }` or `{ success: false, error: }` — no exceptions for control flow
- **Query Objects** — Complex queries in dedicated classes (e.g., `AvailableSlotsQuery`)
- **Metaprogramming (judicious)** — `enum` for status fields, `delegate` for clean interfaces, `class_attribute` for config
- **DRY via shared concerns** — `Timestampable`, `Versionable` (optimistic locking concern)

**ActiveRecord best practices:**
- `includes()` / `preload()` to prevent N+1 (use `strict_loading` in development)
- `find_each` / `in_batches` for bulk operations (never `.all.each`)
- `counter_cache` where applicable
- Index all foreign keys + frequently queried columns
- Composite indexes for multi-column lookups (`[mentor_id, start_time]`)
- `explain` queries in development to verify index usage

**Security hardening:**
- `strong_parameters` (permit only expected params)
- `Brakeman` in CI for static security analysis
- Parameterized queries (ActiveRecord default — never string interpolation in `.where()`)
- UUID primary keys (prevents enumeration attacks)
- CORS restricted to frontend origin
- Rate limiting via `rack-attack`
- `Regexp.timeout` (Rails 8 default) prevents ReDoS

**Memory & performance:**
- Streaming responses for large result sets (if needed)
- `pagy` for pagination (constant memory regardless of total count)
- `pluck` for read-only column access (no AR object instantiation)
- Redis connection pooling via `connection_pool` gem
- Sidekiq concurrency tuned to match Puma workers
- `jbuilder` avoided (memory-heavy); `blueprinter` is allocation-lean

**Migration best practices with strong_migrations:**
- All migrations validated by strong_migrations before execution
- Indexes created concurrently (`disable_ddl_transaction!` + `algorithm: :concurrently`)
- Column additions: never add with default on existing large tables (add column, backfill, then set default)
- Column removals: `self.ignored_columns += ["column_name"]` in model first, remove migration in next deploy
- Foreign keys added in separate migration from column creation
- Use `safety_assured` block only with comment explaining why it's safe

---

### Docker Compose (Updated for Rails)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: mentoring
      POSTGRES_PASSWORD: mentoring
      POSTGRES_DB: mentoring_development
    ports: ["5432:5432"]
    volumes: [postgres_data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mentoring"]
      interval: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes: [redis_data:/data]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5

  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://mentoring:mentoring@postgres:5432/mentoring_development
      REDIS_URL: redis://redis:6379/0
      RAILS_ENV: production
      SECRET_KEY_BASE: ${SECRET_KEY_BASE:-$(openssl rand -hex 64)}
    ports: ["3000:3000"]
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }
    command: >
      sh -c "bin/rails db:prepare &&
             bin/rails db:seed &&
             bundle exec puma -C config/puma.rb"

  sidekiq:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://mentoring:mentoring@postgres:5432/mentoring_development
      REDIS_URL: redis://redis:6379/0
      RAILS_ENV: production
      SECRET_KEY_BASE: ${SECRET_KEY_BASE:-$(openssl rand -hex 64)}
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }
    command: bundle exec sidekiq -C config/sidekiq.yml

  frontend:
    build: ./frontend
    environment:
      VITE_API_URL: http://localhost:3000/api/v1
    ports: ["5173:5173"]
    depends_on: [backend]

volumes:
  postgres_data:
  redis_data:
```

**Note:** Sidekiq runs as a separate container (same image, different command) — proper production pattern. Backend serves API only via Puma.

---

## DECISION FRAMEWORK

After your responses, I'll score each option:

| Criteria | Weight | Score 1-5 |
|----------|--------|-----------|
| 48-hour delivery confidence | 40% | |
| Production correctness | 30% | |
| Team alignment (TechMentor) | 20% | |
| Learning value for me | 10% | |

I'll document your best argument for each and my override reasoning 
in the decision log.

---

## SCOPE (Locked — Documented Cuts)

### In Scope (P0)
- Multi-tenant org/user context (stub auth)
- Browse mentors and open slots
- Book slot: concurrency-safe, no double-booking
- Cancel and reschedule booking
- Idempotent booking API (retried request never duplicates)
- Multi-tenant data isolation at DB layer
- Persisted data model + migrations
- Tests for hard paths: concurrency, idempotency, multi-tenancy
- Real loading / empty / error states
- "My sessions" view (member + mentor perspectives)
- Redis cache for slot listings with invalidation
- Sidekiq for async booking confirmations
- Structured logging + request correlation IDs
- docker-compose up (frontend + backend + postgres + redis)
- README: architecture, tradeoffs, AI usage, what I'd add with more time

### Out of Scope (Explicitly Cut)
1. Real authentication (OAuth, SSO) — stub only
2. 3rd party calendar integration — explicitly out
3. Mentor admin dashboard / availability management — seed slots via script
4. Recurring slot generation — seed script creates sample data
5. Real-time WebSocket/SSE notifications — async job only
6. Full timezone/DST handling — org-level default, document IANA as P2
7. Cancellation windows / penalties — simple check, full policy P2
8. Per-member booking limits — acknowledged, P2
9. Payment integration — out of domain
10. Admin dashboard — P2
11. Mobile-responsive polish — functional over beautiful
12. Full test coverage — hard paths only

---

## DATA MODEL

organizations
├── id: UUID (PK)
├── name: string
├── timezone: string (IANA, default 'UTC')
├── created_at: timestamp

users
├── id: UUID (PK)
├── org_id: UUID (FK, indexed)
├── email: string (unique per org)
├── name: string
├── role: enum ['member', 'mentor', 'admin']
├── created_at: timestamp

mentor_profiles
├── id: UUID (PK)
├── user_id: UUID (FK, unique)
├── bio: text
├── expertise: string[]
├── created_at: timestamp

slots
├── id: UUID (PK)
├── mentor_id: UUID (FK, indexed)
├── start_time: timestamp (UTC, indexed)
├── end_time: timestamp (UTC)
├── status: enum ['available', 'booked', 'cancelled']
├── buffer_minutes: int (default 0)
├── version: int (default 1) — optimistic locking (maps to Rails' `lock_version` convention)
├── created_at: timestamp
├── updated_at: timestamp
├── UNIQUE(mentor_id, start_time)

bookings
├── id: UUID (PK)
├── slot_id: UUID (FK, unique)
├── member_id: UUID (FK, indexed)
├── status: enum ['confirmed', 'cancelled', 'completed']
├── idempotency_key: string (unique, indexed)
├── booked_at: timestamp
├── cancelled_at: timestamp (nullable)
├── created_at: timestamp
├── updated_at: timestamp

---

## API DESIGN
| Method | Path                            | Auth                     | Description                     |
| ------ | ------------------------------- | ------------------------ | ------------------------------- |
| GET    | /api/v1/organizations           | Stub                     | List orgs (selector)            |
| POST   | /api/v1/auth/select-org         | Stub                     | Set org context                 |
| GET    | /api/v1/mentors                 | Org-scoped               | List mentors with profiles      |
| GET    | /api/v1/mentors/:id/slots       | Org-scoped               | Available slots for mentor      |
| POST   | /api/v1/bookings                | Org-scoped + idempotency | Book a slot                     |
| PATCH  | /api/v1/bookings/:id/cancel     | Org-scoped               | Cancel booking                  |
| POST   | /api/v1/bookings/:id/reschedule | Org-scoped               | Reschedule (transactional)      |
| GET    | /api/v1/me/sessions             | Org-scoped               | My bookings as member           |
| GET    | /api/v1/me/mentor-sessions      | Org-scoped               | My bookings as mentor           |
| GET    | /api/v1/health                  | Public                   | Health check (DB, Redis, queue) |


## CONCURRENCY: OPTIMISTIC LOCKING

**Why over pessimistic:** No deadlock risk, scales better, industry 
standard for scheduling systems.

**Flow:**
1. Read slot + version
2. Check status === 'available'
3. UPDATE slots SET status='booked', version=version+1 
   WHERE id=? AND version=?
4. If rowsAffected === 0 → OptimisticConflictError → retry
5. Max 3 retries, exponential backoff: 200ms, 400ms, 800ms
6. Create booking with idempotency_key
7. Enqueue notification
8. Invalidate cache

**Idempotency:** UNIQUE(idempotency_key). On conflict, return existing 
booking with 200 (not 201).

---

## RATE LIMITING

| Endpoint | Limit | Window | Why |
|----------|-------|--------|-----|
| POST /api/v1/bookings | 10 | 1 minute | Prevent slot spam |
| POST /api/v1/bookings/:id/reschedule | 5 | 1 minute | Prevent churn |
| GET /api/v1/mentors/:id/slots | 100 | 1 minute | Protect cache |

Implementation: `rack-attack` gem with Redis cache store for distributed 
consistency (single instance in MVP, but store interface is correct).

---

## TIMEZONE HANDLING

- Storage: UTC in database
- Display: `Intl.DateTimeFormat` with org's IANA timezone
- DST: Handled automatically by Intl API
- Limitation: Org-level only. Per-user override documented as P2.

**Buffer enforcement:** At slot generation (seed script), not booking 
time. `buffer_minutes` field exists for future dynamic management.
Enforced at slot generation (seed script), not booking time
buffer_minutes field exists for future dynamic management
Seed script: slot_end + buffer = next_slot_start
Documented: Dynamic buffer admin UI is P2

---

## CACHING STRATEGY

- Pattern: Cache-aside
- Key: `slots:{mentorId}:{startDate}:{endDate}`
- TTL: 300 seconds (5 minutes)
- Invalidation: On mutation → `DEL slots:{mentorId}:*`
- Warming: Populated on first request (no proactive warming in MVP)

---

## ASYNC / QUEUE ARCHITECTURE

Queue: Sidekiq (Redis-backed)
Jobs: BookingConfirmationJob, BookingCancellationJob, BookingRescheduleJob
Retry: 3 attempts, exponential backoff (sidekiq_options retry: 3)
Transport: Rails.logger (MVP) → ActionMailer + SendGrid (production)

Why off request path: API <100ms, booking succeeds independently of 
notification delivery. Sidekiq processes jobs in a separate container
with its own concurrency pool, isolated from Puma request threads.

---

## DEPLOYMENT: CONTAINERIZED APPLICATION

### Requirement
`docker-compose up` must start the complete application:
- PostgreSQL (migrations + seed data)
- Redis (cache + Sidekiq queue)
- Backend API (Rails 8 + Puma)
- Sidekiq worker (background job processing)
- Frontend SPA (React + Vite)
- Optional: Sidekiq Web UI for queue monitoring (mounted at /sidekiq in development)

### Architecture
┌─────────────────────────────────────────────────────────────┐
│                        Docker Network                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Postgres   │  │    Redis    │  │  Backend (Rails 8)  │  │
│  │   :5432     │  │   :6379     │  │      :3000          │  │
│  │  (migrations│  │ (cache+queue)│  │  (Puma API server)  │  │
│  │   on start) │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│         ▲                ▲                  ▲               │
│         └────────────────┴──────────────────┘               │
│                                              │               │
│                    ┌─────────────────────┐   │               │
│                    │   Sidekiq Worker    │   │               │
│                    │  (background jobs)  │───┘               │
│                    └─────────────────────┘                   │
│                              │                               │
│                    ┌─────────┴─────────┐                     │
│                    │  Frontend (React)  │                     │
│                    │      :5173         │                     │
│                    │  (Vite dev server) │                     │
│                    └───────────────────┘                     │
└─────────────────────────────────────────────────────────────┘

### Health Checks
- Postgres: `pg_isready` before backend starts
- Redis: `redis-cli ping` before backend starts
- Backend: `/health` endpoint (DB + Redis connectivity)
GET /api/v1/health
Response: { "status": "ok", "checks": { "database": "connected", 
"redis": "connected", "queue": "connected" } }

GET /api/v1/health
Response: {
  "status": "ok",
  "checks": {
    "database": "connected",
    "redis": "connected",
    "queue": "connected"
  }
}

## OBSERVABILITY (Detailed)

### Logging
- Tool: Lograge (structured JSON) + RequestStore (per-request context)
- Fields: timestamp, level, message, correlation_id, user_id, org_id, 
  request_path, request_method, response_status, duration_ms
- Output: stdout (Docker captures via Rails.logger)
- Configuration: config/initializers/lograge.rb with custom_payload

### Metrics (Basic)
| Metric | Type | Endpoint |
|--------|------|----------|
| http_requests_total | Counter | `/metrics` (Prometheus format) |
| http_request_duration_seconds | Histogram | `/metrics` |
| db_query_duration_ms | Histogram | `/metrics` |
| cache_hit_total | Counter | `/metrics` |
| cache_miss_total | Counter | `/metrics` |
| sidekiq_jobs_processed | Counter | Sidekiq Web UI |
| sidekiq_jobs_failed | Counter | Sidekiq Web UI |

Implementation: `yabeda-rails` + `yabeda-sidekiq` + `yabeda-prometheus` gems.
MVP: Lograge JSON logs to stdout. Production: Prometheus scrape endpoint + Sidekiq Web UI.


### Startup Order
1. Postgres + Redis start with health checks
2. Backend waits for healthy dependencies, runs `bin/rails db:prepare` + `bin/rails db:seed`
3. Sidekiq worker starts after backend is healthy
4. Frontend starts once backend is up

### Docker Compose Services

See "FINAL STACK DECISION > Docker Compose (Updated for Rails)" section above for the 
canonical docker-compose.yml. The configuration uses:
- `postgres:16-alpine` with healthcheck
- `redis:7-alpine` with healthcheck  
- `backend` (Rails 8 + Puma) — runs `bin/rails db:prepare && bin/rails db:seed && bundle exec puma`
- `sidekiq` (same image, different entrypoint) — runs `bundle exec sidekiq`
- `frontend` (React + Vite)

### Run Instructions

```bash
# 1. Clone and enter directory
cd mentoring-session-booking

# 2. Start all services
docker-compose up

# 3. Wait for health checks (postgres, redis ready)
# Backend will auto-run migrations and seed

# 4. Access application
# Frontend: http://localhost:5173
# API: http://localhost:3000/api/v1
# Sidekiq Web UI: http://localhost:3000/sidekiq (development only)

# 5. Run tests
docker-compose exec backend bundle exec rspec
docker-compose exec frontend npm test
```

UI REFERENCE (GetGist Screenshots)
I have screenshots of my GetGist app (cal.id/gowthamvel-palanivel) showing:
Service card landing page (avatar, title, description, duration pills, schedule button)
Calendar slot selection (month/week/column views, time slot buttons)
Booking form (name, email, notes, guests, add guests)
Confirmation page (meeting details, reschedule/cancel, add to calendar)
For TechMentor, I SIMPLIFY:
Service cards → Mentor cards (avatar, name, expertise, view button)
Calendar views → Simple week grid (date + time slots, book button)
Booking form → One-click confirm (auth stubbed, no form fields)
Confirmation page → Toast + redirect to "My Sessions"
Add "My Sessions" list page (upcoming + past, cancel/reschedule actions)