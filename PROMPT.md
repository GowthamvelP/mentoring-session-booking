# KIRO SPEC MODE PROMPT — MENTORING SYSTEM DESIGN EXERCISE
## System Design Exercise | Mentoring Session Booking System
## Candidate: Gowthamvel Palanivel
## Date: 2026-08-11
## Budget: ~1000 Kiro credits, $20 AI tool budget

---

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
- Bull queue for async booking confirmations
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
├── version: int (default 1) — optimistic locking
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

Implementation: `express-rate-limit` with Redis store for distributed 
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

Queue: Bull (Redis-backed)
Jobs: booking_created, booking_cancelled, booking_rescheduled
Retry: 3 attempts, exponential backoff (2s, 4s, 8s)
Transport: Console.log (MVP) → SendGrid (production)

Why off request path: API &lt;100ms, booking succeeds independently of 
notification delivery.

---

## DEPLOYMENT: CONTAINERIZED APPLICATION

### Requirement
`docker-compose up` must start the complete application:
- PostgreSQL (migrations + seed data)
- Redis (cache + queue)
- Backend API (Express + Prisma)
- Frontend SPA (React + Vite)
- Optional: Bull dashboard for queue monitoring

### Architecture
┌─────────────────────────────────────────────────────────────┐
│                        Docker Network                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Postgres   │  │    Redis    │  │   Backend (Node)    │  │
│  │   :5432     │  │   :6379     │  │      :3000          │  │
│  │  (migrations│  │ (cache+queue)│  │  (API + Bull worker)│  │
│  │   on start) │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│         ▲                ▲                  ▲               │
│         └────────────────┴──────────────────┘               │
│                                              │               │
│                              ┌───────────────┘               │
│                              ▼                               │
│                    ┌─────────────────────┐                   │
│                    │  Frontend (React)   │                   │
│                    │      :5173           │                   │
│                    │   (Vite dev server)   │                   │
│                    └─────────────────────┘                   │
│                              │                               │
│                    ┌─────────┴─────────┐                     │
│                    │  Bull Dashboard   │                     │
│                    │      :3001       │                     │
│                    │  (queue monitor)  │                     │
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
- Tool: Pino (structured JSON)
- Fields: timestamp, level, message, correlation_id, user_id, org_id, 
  request_path, request_method, response_status, duration_ms
- Output: stdout (Docker captures)

### Metrics (Basic)
| Metric | Type | Endpoint |
|--------|------|----------|
| http_requests_total | Counter | `/metrics` (Prometheus format) |
| http_request_duration_seconds | Histogram | `/metrics` |
| db_query_duration_ms | Histogram | `/metrics` |
| cache_hit_total | Counter | `/metrics` |
| cache_miss_total | Counter | `/metrics` |

Implementation: `prom-client` npm package. MVP: console.log metrics. 
Production: Prometheus scrape endpoint.


### Startup Order
1. Postgres + Redis start with health checks
2. Backend waits for healthy dependencies, runs migrations + seed
3. Frontend starts once backend is up
4. Bull dashboard starts for queue visibility

### Docker Compose Services

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: mentoring
      POSTGRES_PASSWORD: mentoring
      POSTGRES_DB: mentoring
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mentoring -d mentoring"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://mentoring:mentoring@postgres:5432/mentoring
      REDIS_URL: redis://redis:6379
    ports:
      - "3000:3000"
    volumes:
      - ./backend:/app
      - /app/node_modules
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: &gt;
      sh -c "npx prisma migrate deploy &&
             npx prisma db seed &&
             npm run dev"

  frontend:
    build: ./frontend
    environment:
      VITE_API_URL: http://localhost:3000/api/v1
    ports:
      - "5173:5173"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    depends_on:
      - backend

  bull-dashboard:
    image: beequeue/bull-monitor:latest
    environment:
      REDIS_URL: redis://redis:6379
    ports:
      - "3001:3000"
    depends_on:
      - redis

volumes:
  postgres_data:
  redis_data:

README addon
## RUN INSTRUCTIONS

```bash
# 1. Clone and enter directory
cd mentoring-mentoring-booking

# 2. Start all services
docker-compose up

# 3. Wait for health checks (postgres, redis ready)
# Backend will auto-run migrations and seed

# 4. Access application
# Frontend: http://localhost:5173
# API: http://localhost:3000/api/v1
# Bull Dashboard: http://localhost:3001

# 5. Run tests
docker-compose exec backend npm test
docker-compose exec frontend npm test

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