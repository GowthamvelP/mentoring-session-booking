# Mentoring Session Booking System

A full-stack mentoring session booking application enabling members to browse mentors, book 1:1 sessions with concurrency safety, and manage their sessions — all within a multi-tenant organizational context.

**Built as:** A production-grade demonstration of scheduling system architecture
**By:** Gowthamvel Palanivel  
**Stack:** Ruby on Rails 8 (API-only) + React 19 + PostgreSQL 16 + Redis 7 + Sidekiq

---

## Quick Start

```bash
# 1. Clone the repository
git clone <repo-url> && cd mentoring-session-booking

# 2. Start all services
docker-compose up --build

# 3. Access the application
# Frontend:        http://localhost:5173
# Backend API:     http://localhost:3000/api/v1
# Sidekiq Web UI:  http://localhost:3000/sidekiq
# Health Check:    http://localhost:3000/api/v1/health

# 4. Run backend tests
docker-compose exec backend bundle exec rspec

# 5. Run frontend tests
docker-compose exec frontend npm run test:run
```

The seed script automatically creates sample data (2 orgs, 4 mentors, 4 members, 40+ slots) — ready to use immediately.

---

## Architecture

```
+---------------------------------------------------------------------+
|                          Docker Network                              |
|                                                                     |
|  +-----------------+  +-----------------+  +--------------------+   |
|  | Frontend        |  | Backend         |  | Sidekiq Worker     |   |
|  | React 19 + Vite |--| Rails 8 + Puma  |--| (background jobs)  |   |
|  | :5173           |  | :3000           |  |                    |   |
|  +-----------------+  +--------+--------+  +---------+----------+   |
|                                |                     |              |
|  +-----------------+  +--------+--------+            |              |
|  | PostgreSQL 16   |  |    Redis 7      |------------+              |
|  | :5432           |  |    :6379        |                           |
|  | - UUID PKs      |  |    - Cache      |                           |
|  | - Row locks     |  |    - Job queue  |                           |
|  | - Constraints   |  |    - Rate limits|                           |
|  +-----------------+  +-----------------+                           |
+---------------------------------------------------------------------+
```

### Backend (Rails 8, API-only)

| Layer | Responsibility |
|-------|---------------|
| Rack Middleware | Rate limiting (rack-attack), CORS, correlation IDs |
| Controller Concerns | Auth stub (X-User-Id/X-Org-Id headers), tenant scoping |
| Controllers | Thin — validate params, call service, render response |
| Services | Business logic — BookingService, CancellationService, RescheduleService, SlotService |
| Models | Validations, associations, scopes — no business logic |
| Serializers | Blueprinter — explicit API contract, no leaking internals |
| Jobs | Sidekiq — async notifications (3 retries, dead letter queue) |

### Frontend (React 19 + TypeScript + Tailwind)

| Layer | Responsibility |
|-------|---------------|
| API Client | Typed Axios with auth header injection + error transform |
| Custom Hooks | TanStack Query — caching, refetching, optimistic updates |
| Pages | Compose hooks + UI primitives, mutually exclusive states |
| UI Components | Dark theme design system — Button, Card, Badge, Skeleton, Toast |

---

## Key Design Decisions & Tradeoffs

### 1. Pessimistic Locking (SELECT FOR UPDATE)

**Chose:** Pessimistic locking for slot booking  
**Over:** Optimistic locking with lock_version + retry loops

**Why:** Single-row point lock by primary key cannot deadlock. Transaction is sub-50ms. Eliminates retry loop complexity (30+ lines of code), exponential backoff, and StaleObjectError handling. The concurrency test proves correctness: 5 threads compete, exactly 1 wins.

**Scaling path:** At horizontal scale with high-contention hot slots, switch to optimistic locking (`lock_version` + retry) to reduce row-lock wait time under sustained concurrent load.

### 2. Two-State Slots (available / booked)

**Chose:** Two states only  
**Over:** Three states (available / booked / cancelled)

**Why:** "Cancelled" on a slot is ambiguous — does it mean mentor withdrew availability, or a booking was cancelled? With two states, the slot simply flips between available and booked based on booking lifecycle. Simpler state machine, fewer bugs.

### 3. Rails 8 API-Only Mode

**Chose:** `rails new --api` with separate React SPA  
**Over:** Full Rails with Hotwire/Turbo, or hybrid with Inertia.js

**Why:** Clean separation of concerns. Backend serves JSON, frontend consumes it. Independent deployment. The API contract (Blueprinter serializers) is explicit and testable. Frontend uses TanStack Query for sophisticated cache management that wouldn't be possible in a server-rendered approach.

### 4. Sidekiq Free (not Pro/Enterprise)

**Chose:** Sidekiq 7 (open source)  
**Over:** Sidekiq Pro ($99/mo) or Enterprise ($179/mo)

**Why:** Free tier provides everything needed: reliable enqueue, retry with exponential backoff, dead letter queue, concurrency control.

**Pro upgrade path:** Unique jobs (replacing our idempotency_key approach at job level), batch operations for bulk notifications, rate limiting per queue.

### 5. acts_as_tenant (not manual scoping)

**Chose:** `acts_as_tenant` gem  
**Over:** Manual `default_scope` or per-query `.where(organization_id: ...)`

**Why:** Automatic scoping prevents the "forgot to scope" bug. Every query is automatically tenant-filtered. The gem raises `ActsAsTenant::Errors::NoTenantSet` if you accidentally query without a tenant — fail-safe by default.

### 6. 1-Hour Cancellation Window

**Chose:** Simple 1-hour check  
**Over:** Full cancellation policy engine (tiered penalties, org-configurable windows)

**Why:** Demonstrates awareness of real-world scheduling constraints without over-engineering. The window is a single-line check. Full policy engine is P2.

---

## Concurrency Safety — How It Works

```
Thread A (books slot)              Thread B (books same slot)
         │                                  │
    BEGIN TRANSACTION                  BEGIN TRANSACTION
         │                                  │ (waits — row locked)
    SELECT FOR UPDATE ← lock                │
    slot.status == 'available' ✓            │
    UPDATE → 'booked'                       │
    INSERT booking                          │
    COMMIT ← release lock                   │
         │                                  ▼
         │                         SELECT FOR UPDATE ← lock acquired
         │                         slot.status == 'booked' ✗
         │                         ROLLBACK → 409 Conflict
    201 Created                    409 Conflict
```

Verified by concurrency test (`spec/services/concurrency_spec.rb`): 5 threads, 1 winner, 0 duplicate bookings.

---

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/organizations` | Public | List organizations |
| POST | `/api/v1/auth/select-org` | Public | Establish session context |
| GET | `/api/v1/health` | Public | Health check (PG, Redis, Sidekiq) |
| GET | `/api/v1/mentors` | Org-scoped | Browse mentors (paginated) |
| GET | `/api/v1/mentors?search=react` | Org-scoped | Filter by name or expertise |
| GET | `/api/v1/mentors/:id/slots` | Org-scoped | Available slots (cached, 300s TTL) |
| POST | `/api/v1/bookings` | Org-scoped | Book a slot (idempotent) |
| PATCH | `/api/v1/bookings/:id/cancel` | Org-scoped | Cancel booking |
| POST | `/api/v1/bookings/:id/reschedule` | Org-scoped | Reschedule booking |
| GET | `/api/v1/me/sessions` | Org-scoped | My sessions (member) |
| GET | `/api/v1/me/mentor_sessions` | Org-scoped | My sessions (mentor) |

### Authentication (Stub)

The frontend provides a user-friendly auth flow:
1. Select your organization from a card picker
2. Choose your user (member or mentor) from the list
3. Click Continue — headers are automatically injected

Under the hood, requests carry `X-User-Id` and `X-Org-Id` headers. The backend validates both exist and belong to the same organization. In production, this would be replaced with JWT tokens from OAuth2/Cognito.

---

## Testing

**154 specs, 0 failures, 92% line coverage.** Run with: `bundle exec rspec`

### Correctness Properties Tested

| # | Property | What It Proves |
|---|----------|---------------|
| P1 | Idempotency round-trip | Same key → same booking, count=1 |
| P2 | Concurrency safety | 5 threads, exactly 1 wins |
| P3 | Cancellation restores availability | Slot flips back to available |
| P4 | Reschedule atomicity | Failure preserves original |
| P5 | Tenant isolation | Org A invisible to Org B |
| P6 | Cancellation window | Rejected within 1 hour |
| P7 | Cache consistency | Mutations invalidate stale cache |
| P8 | Transaction atomicity | Failure rolls back everything |
| P9 | Booking count invariant | Reschedule doesn't create extras |

### Test Structure

```
spec/
├── services/
│   ├── booking_service_spec.rb       # Unit + property tests (idempotency, conflict)
│   ├── cancellation_service_spec.rb  # Cancel logic + 1-hour window enforcement
│   ├── reschedule_service_spec.rb    # Atomic reschedule + rollback
│   ├── slot_service_spec.rb          # Cache-aside + invalidation consistency
│   ├── concurrency_spec.rb           # Multi-threaded double-booking prevention
│   └── tenant_isolation_spec.rb      # Cross-org data isolation
├── requests/
│   ├── bookings_spec.rb              # Full HTTP request cycle (create/cancel/reschedule)
│   ├── mentors_spec.rb               # Pagination, auth enforcement, tenant scoping
│   ├── slots_spec.rb                 # Date params, ISO format, cache-aside
│   ├── sessions_spec.rb              # Member + mentor views, access control
│   ├── organizations_spec.rb         # Org list, user list endpoint
│   ├── auth_spec.rb                  # Select-org success/failure paths
│   ├── health_spec.rb                # All dependency checks + degraded state
│   └── rate_limiting_spec.rb         # Rack::Attack throttle verification
├── jobs/
│   ├── booking_confirmation_job_spec.rb
│   ├── booking_cancellation_job_spec.rb
│   └── booking_reschedule_job_spec.rb
├── middleware/
│   └── correlation_id_middleware_spec.rb
├── models/                           # Validations, associations, scopes, enums
└── factories/                        # factory_bot test data builders
```

### Load Testing (k6)

Validates non-functional requirements under real concurrent HTTP load:

```bash
# Install k6
brew install k6

# Run all load tests
cd load-tests && ./run-all.sh
```

| Script | What It Tests | Expected Result |
|--------|--------------|-----------------|
| `concurrency.js` | 50 VUs booking same slot | Exactly 1 wins, 49 get 409 |
| `idempotency.js` | 100 requests, same key | 1 created, 99 return existing |
| `rate-limiting.js` | 20 burst requests | First 10 pass, then 429 |
| `multi-tenant.js` | Cross-org access | Mismatched user/org → 401 |
| `load-booking-flow.js` | 50 VUs sustained 40s | p95 < 500ms, <10% errors |

---

## How I Leveraged AI

This project was built using Kiro (agentic IDE) with structured spec-driven development:

1. **Requirements Analysis** — AI generated 20 requirements from the brief, then analyzed them for ambiguities. 15 clarifications were resolved through interactive Q&A.

2. **Tech Stack Decision** — AI challenged my initial Node.js bias, modeled Rails vs Python vs Node for this specific problem domain, and recommended Rails based on my experience profile + domain alignment with mentoring platforms.

3. **Architecture Design** — AI proposed pessimistic locking over optimistic (simpler for 48h, same correctness), two-state slots, and API-only mode. I validated against my production experience with GetGist (a Calendly-like scheduling platform I built).

4. **Implementation** — AI executed 45+ tasks from the spec, writing code that followed the architecture patterns defined upfront. I reviewed, corrected, and refined at each checkpoint.

5. **Testing** — AI generated property-based tests for all 9 correctness properties, plus service specs and request specs.

**Key decisions where I overrode AI:** Initial recommendation was Node.js (my "daily driver"). After analyzing the target domain's Rails ecosystem alignment and my own Rails experience, AI correctly reversed its recommendation. The exploration is documented in the project spec files.

**What AI couldn't do:** Domain nuance around slot semantics (two-state vs three-state), cancellation policy tradeoffs, and production scaling paths came from my 9+ years of backend architecture experience and my work on GetGist.

---

## What I Would Add With More Time

### Production Infrastructure
- ECS Fargate (auto-scaling), RDS Multi-AZ, ElastiCache Redis cluster
- ALB + WAF, CloudFront CDN for frontend assets
- Terraform/CDK IaC (I have this experience — see resume)
- Blue/green deployments with Kamal or ECS

### Features (P2)
- Real authentication (OAuth2 + JWT tokens via Devise + Doorkeeper)
- Per-user timezone preferences with automatic slot display conversion
- Configurable cancellation policy engine (per-org rules, tiered penalties)
- Per-member booking limits (org-configurable `max_active_bookings`)
- Recurring slot generation (mentors manage their own availability)
- Real-time notifications via ActionCable/WebSocket
- Email notifications via ActionMailer + SendGrid
- Mentor search powered by Elasticsearch (full-text + expertise faceted search)
- Variable session durations (30/60/90min) configurable per mentor
- Session type templates (career coaching, technical review, pair programming)

### Operational
- Prometheus metrics (yabeda-rails + yabeda-sidekiq)
- Full E2E test suite (Playwright)
- CI/CD pipeline (GitHub Actions with matrix testing)
- Database-level row-level security as additional tenant isolation layer
- Audit trail for all booking mutations (paper_trail gem)
- APM integration (Datadog or New Relic)

---

## Project Structure

```
mentoring-session-booking/
├── backend/                        # Rails 8 API-only
│   ├── app/
│   │   ├── controllers/api/v1/     # Thin API controllers
│   │   ├── services/               # BookingService, CancellationService, RescheduleService, SlotService
│   │   ├── models/                 # ActiveRecord models + Current
│   │   ├── serializers/            # Blueprinter serializers (4 blueprints)
│   │   ├── jobs/                   # Sidekiq background jobs (3 jobs)
│   │   └── middleware/             # CorrelationIdMiddleware
│   ├── config/
│   │   └── initializers/           # sidekiq, rack_attack, lograge, redis, cors
│   ├── db/
│   │   ├── migrate/                # 6 migrations (UUID PKs, constraints, indexes)
│   │   └── seeds.rb                # 2 orgs, 4 mentors, 4 members, 40+ slots
│   └── spec/                       # RSpec test suite
├── frontend/                       # React 19 + Vite + Tailwind
│   └── src/
│       ├── api/                    # Typed API client + functions
│       ├── hooks/                  # TanStack Query hooks
│       ├── components/             # UI primitives + feature components
│       ├── pages/                  # 4 pages (org select, mentors, slots, sessions)
│       ├── context/                # Auth + Toast contexts
│       └── lib/                    # Utilities (idempotency, dates, constants)
├── docs/                           # Architecture diagrams
├── load-tests/                     # k6 load testing scripts (5 scenarios)
├── docker-compose.yml              # Full stack orchestration (5 services)
├── .env.example                    # Required environment variables
```

---

## Tech Stack

| Component | Technology | Why |
|-----------|-----------|-----|
| Backend | Rails 8.1.3 (API-only) | Convention, native patterns, domain alignment |
| Database | PostgreSQL 16 | Row locks, UUID support, JSON, array columns |
| Cache + Queue | Redis 7 | Single infra for Rails.cache + Sidekiq |
| Background Jobs | Sidekiq 7 | Reliable, retry with backoff, dead letters |
| Frontend | React 19 + Vite + Tailwind | Fast builds, typed components, dark theme |
| State Management | TanStack Query v5 | Server state caching + optimistic UI |
| Serialization | Blueprinter | Fast, declarative, no magic |
| Multi-tenancy | acts_as_tenant | Automatic query scoping, fail-safe |
| Rate Limiting | rack-attack | Per-endpoint, Redis-backed |
| Logging | Lograge + RequestStore | Structured JSON + correlation IDs |
| Migrations | strong_migrations | Catches unsafe operations in dev |
| Testing | RSpec + factory_bot + Rantly | Service specs + property-based tests |
| Frontend Tests | Vitest + React Testing Library + MSW | Fast unit tests with API mocking |
| Load Testing | k6 | Concurrent HTTP validation of NFRs |
| Containers | Docker Compose | One-command full stack (5 services) |

---

## Local Development (without Docker)

```bash
# Backend
cd backend
bundle install
rails db:prepare
rails db:seed
bundle exec puma -C config/puma.rb

# Sidekiq (separate terminal)
cd backend
bundle exec sidekiq

# Frontend (separate terminal)
cd frontend
npm install
npm run dev
```

Requires: Ruby 3.3+, Node 20+, PostgreSQL 16, Redis 7 running locally.
