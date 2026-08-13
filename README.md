# Mentoring Session Booking System

A full-stack mentoring session booking application enabling members to browse mentors, book 1:1 sessions with concurrency safety, and manage their sessions — all within a multi-tenant organizational context.

**Built as:** A production-grade demonstration of scheduling system architecture  
**By:** Gowthamvel Palanivel  
**Stack:** Ruby on Rails 8 (API-only) + React 19 + PostgreSQL 16 + Redis 7 + Sidekiq

---

## Prior Experience & Scope Discipline

I previously built [GetGist](https://getgist.me/gowthamvelpalanivel), a Calendly-class scheduling platform with calendar integration, conflict detection, and availability rules. I know this domain deeply — which is exactly why I scoped aggressively for this 48-hour exercise. OAuth calendar sync, recurring slot generation, configurable cancellation policies, and variable session durations were explicitly cut so I could go deep on concurrency safety, idempotency, multi-tenancy, AI-native architecture, and production observability. Depth and judgment over breadth.


---

## Quick Start

```bash
# 1. Clone and start
git clone <repo-url> && cd mentoring-session-booking
docker-compose up --build

# 2. Access the application
# Frontend:        http://localhost:5173
# Backend API:     http://localhost:3000/api/v1
# Sidekiq Web UI:  http://localhost:3000/sidekiq
# Health Check:    http://localhost:3000/api/v1/health

# 3. Run tests
docker-compose exec backend bundle exec rspec       # 252 specs, 98.36% coverage
docker-compose exec frontend npm run test:run       # Vitest + RTL
```

The seed script creates sample data (2 orgs, 4 mentors, 4 members, 40+ slots) — ready to use immediately.

---

## Architecture

> 📊 **Detailed diagrams:** See [docs/DIAGRAMS.md](docs/DIAGRAMS.md) for ER diagram, service architecture, booking flow sequence, and concurrency safety visualization (Mermaid — renders on GitHub).

```
+---------------------------------------------------------------------+
|                          Docker Network                              |
|  +-----------------+  +-----------------+  +--------------------+   |
|  | Frontend        |  | Backend         |  | Sidekiq Worker     |   |
|  | React 19 + Vite |--| Rails 8 + Puma  |--| (background jobs)  |   |
|  | :5173           |  | :3000           |  |                    |   |
|  +-----------------+  +--------+--------+  +---------+----------+   |
|                                |                     |              |
|  +-----------------+  +--------+--------+            |              |
|  | PostgreSQL 16   |  |    Redis 7      |------------+              |
|  | - UUID PKs      |  |    - Cache      |                           |
|  | - pg_trgm GIN   |  |    - Job queue  |                           |
|  | - Row locks     |  |    - Rate limits|                           |
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
| Jobs | Sidekiq — async notifications, AI briefs (3 retries, dead letter queue) |

### Frontend (React 19 + TypeScript + Tailwind)

| Layer | Responsibility |
|-------|---------------|
| API Client | Typed Axios with auth header injection + error transform |
| Custom Hooks | TanStack Query — caching, refetching, optimistic updates |
| Pages | Compose hooks + UI primitives, mutually exclusive states |
| UI Components | Dark theme design system — Button, Card, Badge, Skeleton, Toast |

---

## Features

### Core Booking
- **Browse mentors** — paginated list with GIN trigram search (name + expertise)
- **View available slots** — cached (300s TTL), date-filtered, with buffer enforcement
- **Book sessions** — pessimistic locking, idempotent (deduplication key), per-member booking limits
- **Cancel sessions** — 1-hour cancellation window, cancellation reason field, slot auto-release
- **Reschedule sessions** — atomic swap (old released, new booked in single transaction)
- **My Sessions** — separate member/mentor views with status filtering

### Notifications & UX
- **In-app notification system** — bell icon with unread count badge, real-time (synchronous creation, zero-latency on action), mark read/mark all read, 30s background poll
- **Pre-booking confirmation modal** — shows session details before committing
- **Post-booking confirmation modal** — success state with next steps
- **Cancel confirmation modal** — with optional reason input
- **Reschedule confirmation modal** — shows old/new slot comparison
- **Add to Calendar** — Google Calendar link + .ics file download

### Scheduling Intelligence
- **Per-booking timezone storage** — stored at booking time; notifications/emails use recipient's personal timezone (Google Calendar pattern: same UTC moment, different display per viewer)
- **Timezone selector** — full IANA timezone list via `@vvo/tzdb`
- **Runtime buffer enforcement** — configurable minutes between mentor sessions
- **Per-member booking limits** — configurable per organization (`max_active_bookings`)

### Search
- **GIN trigram search** — `pg_trgm` extension with similarity matching on mentor names
- **Expertise array search** — GIN index on PostgreSQL arrays with ILIKE matching

---

## AI-Native Architecture

This project demonstrates how production applications can expose machine-readable interfaces for AI agents.

### SKILL.md — Agent Skill File
A structured document at project root that gives AI coding assistants immediate context: architecture rules, file organization, common tasks, database conventions, and testing patterns. Eliminates the "ramp-up" phase for AI assistants.

### AI Context API — `GET /api/v1/ai/context`
Machine-readable endpoint returning system metadata, schema definitions, conventions, available endpoints, and AI feature flags. Enables autonomous agents to understand the system without reading source code.

### MCP Server — Model Context Protocol
Full MCP implementation with 8 tools:

| Tool | Description |
|------|-------------|
| `list_mentors` | Search/browse mentors with expertise filtering |
| `get_mentor_profile` | Detailed mentor profile (bio, expertise, buffer settings) |
| `get_booking_details` | Full booking details (slot, mentor, member, status) |
| `reschedule_booking` | Atomic reschedule to a new slot |
| `list_slots` | Get available slots for a mentor (date range) |
| `book_slot` | Book a session (with timezone) |
| `cancel_booking` | Cancel with reason (respects 1-hour window) |
| `my_sessions` | View member's sessions (status filter) |

Endpoints: `GET /api/v1/ai/mcp/tools` (definitions) + `POST /api/v1/ai/mcp/call` (execution)

MCP stdio server (`mcp-server/server.js`) enables Kiro/Cursor to call tools directly via JSON-RPC.

### Pre-Session Brief Job
Async Sidekiq job (`BookingBriefJob`) on dedicated `ai` queue generates AI-powered preparation notes for mentors. Currently runs in stub mode; production path documented for OpenAI GPT-4o-mini integration with token tracking.

### Documented Future Architecture
- **Mentor semantic matching** — pgvector embeddings for natural language mentor discovery
- **Natural language booking** — LLM function calling for conversational scheduling
- **Codebase RAG** — Self-onboarding for AI agents via indexed documentation

---

## Key Design Decisions

### 1. Pessimistic Locking (SELECT FOR UPDATE)
Single-row point lock by primary key. Transaction is sub-50ms. Eliminates retry loop complexity (30+ lines), exponential backoff, and StaleObjectError handling. Concurrency test proves correctness: 5 threads compete, exactly 1 wins.

### 2. Two-State Slots (available / booked)
"Cancelled" on a slot is ambiguous. With two states, the slot flips between available and booked based on booking lifecycle. Simpler state machine, fewer bugs.

### 3. acts_as_tenant (not manual scoping)
Automatic query scoping prevents "forgot to scope" bugs. Raises `NoTenantSet` if you query without a tenant — fail-safe by default.

### 4. Buffer Validation at Booking Time
Runtime enforcement (not just UI). Adjacent booked slots within `buffer_minutes` are detected via SQL range query. Prevents back-to-back sessions even under concurrent load.

---

## Concurrency Safety

```
Thread A (books slot)              Thread B (books same slot)
    BEGIN TRANSACTION                  BEGIN TRANSACTION
    SELECT FOR UPDATE <- lock          | (waits)
    slot.status == 'available' OK      |
    UPDATE -> 'booked'                 |
    INSERT booking                     |
    COMMIT <- release lock             v
                                   SELECT FOR UPDATE <- acquired
                                   slot.status == 'booked' FAIL
                                   ROLLBACK -> 409 Conflict
    201 Created                    409 Conflict
```

Verified by `spec/services/concurrency_spec.rb`: 5 threads, 1 winner, 0 duplicate bookings.

---

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/organizations` | Public | List organizations |
| POST | `/api/v1/auth/select-org` | Public | Establish session context |
| GET | `/api/v1/health` | Public | Health check (PG, Redis, Sidekiq) |
| GET | `/api/v1/mentors` | Org-scoped | Browse mentors (paginated, trigram search) |
| GET | `/api/v1/mentors/:id/slots` | Org-scoped | Available slots (cached, 300s TTL) |
| POST | `/api/v1/bookings` | Org-scoped | Book a slot (idempotent, buffer-validated) |
| PATCH | `/api/v1/bookings/:id/cancel` | Org-scoped | Cancel booking (with reason) |
| POST | `/api/v1/bookings/:id/reschedule` | Org-scoped | Reschedule booking (atomic swap) |
| GET | `/api/v1/me/sessions` | Org-scoped | My sessions (member) |
| GET | `/api/v1/me/mentor_sessions` | Org-scoped | My sessions (mentor) |
| GET | `/api/v1/notifications` | Org-scoped | List notifications + unread count |
| PATCH | `/api/v1/notifications/:id/mark_read` | Org-scoped | Mark notification read |
| POST | `/api/v1/notifications/mark_all_read` | Org-scoped | Mark all notifications read |
| GET | `/api/v1/ai/context` | Public | AI-readable system context |
| GET | `/api/v1/ai/mcp/tools` | Org-scoped | MCP tool definitions |
| POST | `/api/v1/ai/mcp/call` | Org-scoped | Execute MCP tool |

---

## Testing

**252 specs, 0 failures, 98.36% line coverage.** Run with: `bundle exec rspec`

### Correctness Properties Tested

| # | Property | What It Proves |
|---|----------|---------------|
| P1 | Idempotency round-trip | Same key -> same booking, count=1 |
| P2 | Concurrency safety | 5 threads, exactly 1 wins |
| P3 | Cancellation restores availability | Slot flips back to available |
| P4 | Reschedule atomicity | Failure preserves original |
| P5 | Tenant isolation | Org A invisible to Org B |
| P6 | Cancellation window | Rejected within 1 hour |
| P7 | Cache consistency | Mutations invalidate stale cache |
| P8 | Transaction atomicity | Failure rolls back everything |
| P9 | Booking count invariant | Reschedule doesn't create extras |

### Load Testing (k6)

6 scenarios validating non-functional requirements under real concurrent HTTP load:

```bash
cd load-tests && bash run-dev.sh
```

| Script | What It Tests | Expected Result |
|--------|--------------|-----------------|
| `concurrency.js` | 50 VUs booking same slot | Exactly 1 wins, 49 get 409 |
| `idempotency.js` | 100 requests, same key | 1 created, 99 return existing |
| `rate-limiting.js` | 20 burst requests | First 10 pass, then 429 |
| `multi-tenant.js` | Cross-org access | Mismatched user/org -> 401 |
| `booking-flow.js` | 50 VUs sustained 40s | p95 < 500ms, <10% errors |
| `reschedule-concurrency.js` | Concurrent reschedule attempts | Atomic swap, no orphaned slots |

---

## Tech Stack

| Component | Technology | Why |
|-----------|-----------|-----|
| Backend | Rails 8.1.3 (API-only) | Convention, native patterns, domain alignment |
| Database | PostgreSQL 16 | Row locks, UUID support, JSON, array columns |
| Search | pg_trgm + pg_search | GIN trigram indexes, similarity ranking |
| Timezone | @vvo/tzdb | Complete IANA timezone list, lightweight |
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

## Project Structure

```
mentoring-session-booking/
├── backend/                          # Rails 8 API-only
│   ├── app/
│   │   ├── controllers/api/v1/       # Versioned API controllers
│   │   │   ├── ai/                   # AI Context + MCP Server
│   │   │   ├── me/                   # Member/mentor session views
│   │   │   ├── notifications_controller.rb
│   │   │   └── ...
│   │   ├── services/                 # Business logic (4 services + concerns)
│   │   ├── models/                   # ActiveRecord + acts_as_tenant
│   │   ├── serializers/              # Blueprinter serializers
│   │   ├── jobs/                     # Sidekiq jobs (4 jobs including AI brief)
│   │   └── middleware/               # CorrelationIdMiddleware
│   ├── db/migrate/                   # 8 migrations (UUID PKs, GIN indexes, constraints)
│   ├── db/seeds.rb                   # 2 orgs, 4 mentors, 4 members, 40+ slots
│   └── spec/                         # 204 specs (services, requests, models, jobs)
├── frontend/                         # React 19 + Vite + Tailwind
│   └── src/
│       ├── api/                      # Typed API client + functions
│       ├── hooks/                    # TanStack Query hooks
│       ├── components/               # UI primitives + feature components
│       ├── pages/                    # 5 pages (org select, mentors, slots, sessions, notifications)
│       ├── context/                  # Auth + Toast contexts
│       └── lib/                      # Utilities (idempotency, dates, timezones)
├── load-tests/                       # k6 load testing (6 scenarios)
├── .kiro/
│   ├── skills/architecture.md        # Agent skill file for AI assistants
│   ├── steering/conventions.md       # AI coding conventions
│   └── specs/                        # Kiro spec-driven development artifacts
├── SKILL.md                          # Top-level AI agent skill file
├── docker-compose.yml                # Full stack orchestration (5 services)
└── .env.example                      # Required environment variables
```

---

## What I Would Add With More Time

### Production Infrastructure
- ECS Fargate (auto-scaling), RDS Multi-AZ, ElastiCache Redis cluster
- ALB + WAF, CloudFront CDN for frontend assets
- Terraform/CDK IaC, blue/green deployments with Kamal or ECS

### Features (P2)
- **Reminder notifications** — Scheduled email + in-app reminders (24h and 1h before session). Implementation: `SessionReminderJob` runs on a Sidekiq cron schedule (`sidekiq-cron` gem), queries bookings where `slot.start_time` is within the reminder window, creates Notification records + delivers emails via BookingMailer. Respects user timezone and notification preferences. Idempotent (checks if reminder already sent via `notification_type + booking_id` uniqueness).
- Real authentication (OAuth2 + JWT via Devise + Doorkeeper)
- Google/Apple/Outlook calendar sync (OAuth for conflict detection)
- Mentor settings page (notification preferences, buffer config)
- Admin dashboard for org-level analytics
- Configurable cancellation policy engine (per-org rules, tiered penalties)
- Recurring slot generation (mentors manage own availability)
- Real-time push notifications via ActionCable/WebSocket (currently using synchronous creation + polling — evaluated WebSocket and chose polling for MVP simplicity)
- Variable session durations (30/60/90min) per mentor
- Session type templates (career coaching, technical review, pair programming)

### AI Features (P2)
- OpenAI integration for live pre-session briefs (GPT-4o-mini)
- pgvector embeddings for mentor semantic matching
- Natural language booking via LLM function calling
- Codebase RAG for AI self-onboarding

### Observability & Metrics (P2)
- **Prometheus `/metrics` endpoint** — `yabeda-rails` + `yabeda-sidekiq` + `yabeda-prometheus` gems. Exposes: `http_requests_total`, `http_request_duration_seconds` (histogram), `sidekiq_jobs_processed_total`, `sidekiq_jobs_failed_total`, `cache_hit_ratio`. Scraped by Prometheus, visualized in Grafana. Implementation: add gems, create `config/initializers/yabeda.rb` with metric definitions, mount `Yabeda::Prometheus::Exporter` at `/metrics`.
- **Coverage reports** — SimpleCov generates HTML reports locally (`backend/coverage/`). In CI, uploaded as artifacts via `actions/upload-artifact@v4`. Coverage threshold enforced at 90% — build fails if below. Reports are gitignored (regenerated on every test run).

### E2E Testing (P2)
- **Playwright test suite** — Full browser automation covering: org selection → mentor browse → slot booking → confirmation modal → session list → cancel → reschedule flow. Implementation: `npx playwright init`, configure headless Chromium in Docker (`playwright.config.ts`), MSW disabled (hits real API against test DB). CI: separate job with `services: [postgres, redis, backend]`, runs after unit tests pass. Covers: timezone selector interaction, notification bell updates, optimistic UI rollback on conflict.

### Additional Operational
- CI/CD pipeline (GitHub Actions with matrix testing)
- Database-level row-level security as additional tenant isolation
- Audit trail for all booking mutations (paper_trail gem)
- APM integration (Datadog or New Relic)

---

## How I Leveraged AI

This project was built using **Kiro** (agentic IDE) with structured spec-driven development:

1. **Requirements Analysis** — AI generated 20 requirements, then analyzed for ambiguities. 15 clarifications resolved through interactive Q&A.
2. **Architecture Design** — AI proposed pessimistic locking, two-state slots, and API-only mode. Validated against production experience.
3. **Implementation** — AI executed 45+ tasks from the spec. I reviewed, corrected, and refined at each checkpoint.
4. **Testing** — AI generated property-based tests for all 9 correctness properties, plus service and request specs.
5. **AI-Native Features** — AI designed and implemented the MCP server, context API, and pre-session brief architecture.

**Key decisions where I overrode AI:** Initial Node.js recommendation reversed after analyzing Rails ecosystem alignment + my experience. Domain nuance around slot semantics, cancellation policy tradeoffs, and scaling paths came from 9+ years of backend architecture experience.

---

## Local Development (without Docker)

```bash
# Backend
cd backend && bundle install && rails db:prepare && rails db:seed
bundle exec puma -C config/puma.rb
bundle exec sidekiq  # separate terminal

# Frontend
cd frontend && npm install && npm run dev
```

Requires: Ruby 3.3+, Node 20+, PostgreSQL 16 (with pg_trgm extension), Redis 7.
