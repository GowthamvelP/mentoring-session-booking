# Architecture — Mentoring Session Booking System

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DOCKER NETWORK                                  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         APPLICATION LAYER                             │  │
│  │                                                                       │  │
│  │  ┌─────────────────────┐         ┌─────────────────────┐            │  │
│  │  │   Frontend (React)  │ ──────> │  Backend (Rails 8)  │            │  │
│  │  │   :5173             │  HTTP   │  :3000              │            │  │
│  │  │                     │  JSON   │                     │            │  │
│  │  │  • React 18 + Vite  │         │  • Puma web server  │            │  │
│  │  │  • TanStack Query   │         │  • API-only mode    │            │  │
│  │  │  • Tailwind CSS     │         │  • Blueprinter JSON │            │  │
│  │  │  • Axios client     │         │  • rack-attack      │            │  │
│  │  └─────────────────────┘         │  • acts_as_tenant   │            │  │
│  │                                   │  • Lograge logging  │            │  │
│  │                                   └──────────┬──────────┘            │  │
│  │                                              │                        │  │
│  │                                   ┌──────────┴──────────┐            │  │
│  │                                   │  Sidekiq Worker     │            │  │
│  │                                   │  (same Docker image)│            │  │
│  │                                   │                     │            │  │
│  │                                   │  • BookingConfirm   │            │  │
│  │                                   │  • BookingCancel    │            │  │
│  │                                   │  • BookingReschedule│            │  │
│  │                                   └──────────┬──────────┘            │  │
│  └───────────────────────────────────────────────┼───────────────────────┘  │
│                                                  │                           │
│  ┌───────────────────────────────────────────────┼───────────────────────┐  │
│  │                          DATA LAYER           │                        │  │
│  │                                               │                        │  │
│  │  ┌─────────────────────┐         ┌───────────┴─────────┐            │  │
│  │  │   PostgreSQL 16     │         │     Redis 7         │            │  │
│  │  │   :5432             │         │     :6379           │            │  │
│  │  │                     │         │                     │            │  │
│  │  │  • UUID PKs         │         │  • Cache store      │            │  │
│  │  │  • Foreign keys     │         │    (Rails.cache)    │            │  │
│  │  │  • Row-level locks  │         │  • Sidekiq queue    │            │  │
│  │  │  • UNIQUE indexes   │         │  • Rate limit state │            │  │
│  │  │  • pgcrypto ext     │         │  • Session store    │            │  │
│  │  └─────────────────────┘         └─────────────────────┘            │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Request Flow — Booking a Slot

```
Member clicks "Book" on slot
         │
         ▼
┌─────────────────┐
│   Frontend      │  Generates idempotency_key (UUID v4)
│   (React)       │  Disables button, shows "Booking..."
└────────┬────────┘
         │ POST /api/v1/bookings
         │ Headers: X-User-Id, X-Org-Id, Idempotency-Key
         ▼
┌─────────────────┐
│  Rack Middleware │
│                 │  1. rack-attack: rate limit check (10/min)
│                 │  2. rack-cors: CORS headers
│                 │  3. RequestStore: generate correlation_id
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  BaseController │
│  (Concerns)     │  1. Authenticatable: parse X-User-Id → Current.user
│                 │  2. Tenantable: parse X-Org-Id → set_current_tenant
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Bookings       │
│  Controller     │  Thin: validates params, calls service, renders response
│  #create        │
└────────┬────────┘
         │ BookingService.call(slot_id:, member:, idempotency_key:)
         ▼
┌─────────────────────────────────────────────────────┐
│                   BookingService                      │
│                                                      │
│  1. Check idempotency_key in bookings table          │
│     └─ If exists → return existing booking (200)     │
│                                                      │
│  2. BEGIN TRANSACTION                                │
│     ├─ SELECT * FROM slots WHERE id=? FOR UPDATE     │
│     ├─ Validate slot.status == 'available'           │
│     │   └─ If not → ROLLBACK, return :conflict       │
│     ├─ UPDATE slots SET status='booked'              │
│     ├─ INSERT INTO bookings (confirmed)              │
│     └─ COMMIT                                        │
│                                                      │
│  3. Post-commit:                                     │
│     ├─ Rails.cache.delete_matched("slots:mentor:*")  │
│     └─ BookingConfirmationJob.perform_async(id)      │
│                                                      │
│  Return: { success: true, booking: record }          │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Controller     │  render json: BookingBlueprint.render(booking), status: 201
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Frontend      │  Success toast → 1-2s delay → redirect to My Sessions
│   (React)       │  Invalidate TanStack Query cache for slots
└─────────────────┘
```

---

## Concurrency Safety (Pessimistic Locking)

```
    Thread A                          Thread B
    (Member 1 books slot X)           (Member 2 books slot X)
         │                                 │
         ▼                                 ▼
    BEGIN TRANSACTION                 BEGIN TRANSACTION
         │                                 │
         ▼                                 │ (waits — row locked)
    SELECT * FROM slots               │
    WHERE id = X                       │
    FOR UPDATE                         │
    ← acquires row lock                │
         │                                 │
         ▼                                 │
    slot.status == 'available' ✓       │
         │                                 │
         ▼                                 │
    UPDATE slots SET status='booked'   │
    INSERT booking (confirmed)         │
    COMMIT                             │
    ← releases lock                        │
         │                                 ▼
         │                            SELECT * FROM slots
         │                            WHERE id = X
         │                            FOR UPDATE
         │                            ← acquires lock (slot now 'booked')
         │                                 │
         │                                 ▼
         │                            slot.status == 'booked' ✗
         │                            ROLLBACK
         │                            ← return 409 Conflict
         ▼                                 ▼
    201 Created                       409 Conflict
    (booking confirmed)               (slot no longer available)
```

---

## Data Model (ERD)

```
┌─────────────────────┐
│   organizations     │
├─────────────────────┤
│ id          UUID PK │
│ name        string  │
│ timezone    string  │──────────────────────────┐
│ created_at  ts      │                          │
│ updated_at  ts      │                          │
└─────────────────────┘                          │
         │ has_many                              │
         ▼                                       │
┌─────────────────────┐                          │
│      users          │                          │
├─────────────────────┤                          │
│ id          UUID PK │                          │
│ org_id      UUID FK │◄─────────────────────────┘
│ email       string  │  UNIQUE(org_id, email)
│ name        string  │
│ role        enum    │  [member, mentor]
│ created_at  ts      │
│ updated_at  ts      │
└─────────────────────┘
    │ has_one         │ has_many (as mentor)     │ has_many (as member)
    ▼                 ▼                          ▼
┌──────────────┐  ┌─────────────────────┐  ┌─────────────────────────┐
│mentor_profiles│  │       slots         │  │       bookings          │
├──────────────┤  ├─────────────────────┤  ├─────────────────────────┤
│ id    UUID PK│  │ id          UUID PK │  │ id              UUID PK │
│ user_id  FK  │  │ mentor_id   UUID FK │  │ slot_id         UUID FK │──┐
│ bio     text │  │ org_id      UUID FK │  │ member_id       UUID FK │  │
│ expertise [] │  │ start_time  ts (UTC)│  │ org_id          UUID FK │  │
│ created_at ts│  │ end_time    ts (UTC)│  │ status          enum    │  │
└──────────────┘  │ status      enum    │  │   [confirmed,cancelled, │  │
                  │  [available, booked] │  │    completed]           │  │
                  │ created_at  ts      │  │ idempotency_key string  │  │
                  │ updated_at  ts      │  │   UNIQUE                │  │
                  │                     │  │ booked_at       ts      │  │
                  │ UNIQUE(mentor_id,   │  │ cancelled_at    ts      │  │
                  │        start_time)  │  │ created_at      ts      │  │
                  └─────────────────────┘  │ updated_at      ts      │  │
                           ▲ has_one       └─────────────────────────┘  │
                           └────────────────────────────────────────────┘
```

---

## Caching Strategy

```
                    READ PATH
                    ─────────
Frontend request → GET /mentors/:id/slots?start=&end=
                         │
                         ▼
              ┌─────────────────────┐
              │  Redis Cache Check  │
              │  Key: "slots:123:   │
              │   2026-08-11:       │
              │   2026-08-18"       │
              └──────────┬──────────┘
                    ┌────┴────┐
                    │         │
               HIT ▼    MISS ▼
          Return cached    Query PostgreSQL
          response         Cache result (TTL: 300s)
                           Return fresh response


                    WRITE PATH (Invalidation)
                    ──────────────────────────
BookingService / CancellationService / RescheduleService
                         │
                    On success:
                         │
                         ▼
              ┌─────────────────────┐
              │  Rails.cache.       │
              │  delete_matched(    │
              │   "slots:#{         │
              │    mentor_id}:*")   │
              └─────────────────────┘
                         │
              Next read request repopulates cache
```

---

## Backend Architecture (Rails Layers)

```
┌──────────────────────────────────────────────────────────┐
│                    RACK MIDDLEWARE                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │rack-attack│  │rack-cors │  │ lograge  │  │request │  │
│  │(throttle) │  │ (CORS)   │  │ (logging)│  │ store  │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘  │
└──────────────────────────┬───────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────┐
│                    CONTROLLER LAYER                       │
│  BaseController (Api::V1)                                │
│  ├── include Authenticatable  (X-User-Id → Current.user) │
│  ├── include Tenantable       (X-Org-Id → tenant scope)  │
│  ├── rescue_from handlers     (consistent error JSON)    │
└──────────────────────────┬───────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────┐
│                    SERVICE LAYER                          │
│  BookingService.call(slot_id:, member:, idempotency_key:)│
│  CancellationService.call(booking:, user:)               │
│  RescheduleService.call(booking:, new_slot_id:, user:)   │
│  Returns: { success: bool, booking/error }               │
└──────────────────────────┬───────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────┐
│                    QUERY / CACHE LAYER                    │
│  AvailableSlotsQuery.new(mentor_id:, dates:).call        │
│  Rails.cache.fetch("slots:#{id}:#{dates}", expires_in:)  │
└──────────────────────────┬───────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────┐
│                    MODEL LAYER                            │
│  Organization, User, MentorProfile, Slot, Booking        │
│  • Validations, associations, scopes, enums              │
│  • NO business logic in models                           │
└──────────────────────────┬───────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────┐
│                    SERIALIZER LAYER (Blueprinter)         │
│  MentorBlueprint, SlotBlueprint, BookingBlueprint        │
│  • Defines API contract — never exposes internals        │
└──────────────────────────────────────────────────────────┘
```

---

## Ports & Endpoints

| Port | Service | URL |
|------|---------|-----|
| 5173 | Frontend (React + Vite) | http://localhost:5173 |
| 3000 | Backend API (Rails + Puma) | http://localhost:3000/api/v1 |
| 3000 | Sidekiq Web UI (dev only) | http://localhost:3000/sidekiq |
| 5432 | PostgreSQL | internal only |
| 6379 | Redis | internal only |

---

## Tech Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | React 18, Vite, Tailwind, TanStack Query | SPA with optimistic UI |
| Backend | Rails 8 (API-only), Puma | JSON API server |
| Database | PostgreSQL 16 | Primary store + row locks |
| Cache/Queue | Redis 7 | Rails.cache + Sidekiq |
| Jobs | Sidekiq (free) | Async notifications |
| Serialization | Blueprinter | JSON response shapes |
| Rate Limiting | rack-attack | Per-endpoint throttle |
| Multi-tenancy | acts_as_tenant | Automatic scoping |
| Logging | Lograge + RequestStore | Structured JSON logs |
| Testing | RSpec, factory_bot, Rantly | Unit + property tests |
| Deploy | Docker Compose | Full stack orchestration |
