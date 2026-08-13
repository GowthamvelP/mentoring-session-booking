# QA Remediation Spec — P0 & P1 Gaps

**Scope:** Production safety fixes identified during QA pass. Fix P0 tonight; have P1 answers ready with documented paths.
**Constraint:** No new gems. Backward-compatible. All changes tested.

---

## P0: Fix Tonight (DB Constraints + Auth + Idempotency)

| # | Gap | Problem | Fix | Files | Test Required |
|---|---|---|---|---|---|
| 1 | **No DB unique constraint on active bookings per slot** | Service-layer lock can be bypassed by bugs/console/manual SQL. Two active bookings for one slot possible. | Partial unique index: `add_index :bookings, :slot_id, unique: true, where: "status != 'cancelled'"`. Rescue `RecordNotUnique` → 409. | `db/migrate/xxx_add_unique_index_bookings_slot_id.rb`, `app/models/booking.rb`, `app/services/booking_service.rb` | Request spec: bypass service layer, attempt duplicate insert via raw SQL/transaction, assert DB raises. |
| 2 | **Idempotency key has no DB unique index** | Two identical requests to different Puma workers create duplicate bookings. | Unique index on `[:idempotency_key, :organization_id]` where `idempotency_key IS NOT NULL`. Rescue `RecordNotUnique` → return existing booking. | `db/migrate/xxx_add_unique_index_idempotency_key.rb`, `app/services/booking_service.rb` | Request spec: 10 parallel reqs, same key → 1 created, 9 return existing with 200. |
| 3 | **Stubbed auth allows arbitrary impersonation** | Any `X-User-Id` + `X-Org-Id` combo is accepted. Cross-org access possible. | Concern `ValidateMembership`: check `User.exists?(id: uid, organization_id: oid)`. Return 401 if mismatch. Apply to `Api::V1::BaseController`. | `app/controllers/concerns/validate_membership.rb`, `app/controllers/api/v1/base_controller.rb` | Request specs: valid→200; valid user/wrong org→401; missing headers→401; non-existent user→401. |
| 4 | **Reschedule rollback not proven on failure** | If new booking fails (slot taken, max limit), original booking may be lost or original slot released. | Add spec: mock `BookingService` to raise during new booking. Assert original booking still `confirmed` and original slot still `booked`. Verify single transaction wraps both cancel + book. | `spec/services/reschedule_service_spec.rb` | Service spec: simulate failure mid-reschedule, assert no orphaned state. |
| 5 | **Sidekiq notification jobs are not idempotent** | Retry after SMTP timeout sends duplicate emails and duplicate in-app notifications. | Add `notification_deliveries` table: `booking_id`, `notification_type`, `channel`, `delivered_at`. Unique index on `[:booking_id, :notification_type, :channel]`. Skip if `NotificationDelivery.exists?`. | `db/migrate/xxx_create_notification_deliveries.rb`, `app/models/notification_delivery.rb`, `app/jobs/notification_job.rb` | Job spec: enqueue same notification twice → assert `ActionMailer::Base.deliveries.count == 1` and in-app count == 1. |

---

## P1: Document with Fix Plan (Have the Answer Ready)

| # | Gap | Problem | Production Fix Path | Test / Proof Required |
|---|---|---|---|---|
| 6 | **Cache invalidation race condition** | Booking commits, Redis invalidation fails (network blip). Or read happens between commit and invalidation. Stale slot shown. | Best-effort now. Production: Redis transactions for invalidation, or CDC (PgLogical/Debezium) async invalidation stream. Frontend 5-min staleTime limits blast radius. | Document in `QA_FIXES.md`. Add a note in `BookingService#invalidate_cache`. |
| 7 | **Booking limit check is non-atomic** | Two threads check Alice's count (2/3). Both book. Now she has 4. | Limit check happens outside slot lock. Fix: advisory lock on `user_id` during booking, or denormalize `active_bookings_count` on `users` with DB constraint. | Add a concurrency spec: two threads hit limit boundary simultaneously, assert only one succeeds. |
| 8 | **No foreign key constraints** | `belongs_to :mentor` but no FK. Deleting a mentor orphans bookings or causes `nil` mentor references. | Add FKs: `bookings.mentor_id` → `mentors` (`on_delete: :restrict`), `notifications.user_id` → `users` (`on_delete: :cascade`). | Migration + model spec: assert `ActiveRecord::InvalidForeignKey` on delete. |
| 9 | **MCP has no scoped auth or rate limits** | AI agent loops `book_slot`. No per-tool scopes, no audit trail. | API keys with scopes (`mcp:read` vs `mcp:book`). Stricter rate limits on `/ai/*`. Audit log table for every MCP invocation. | Add middleware spec: unscoped token → 403; scoped token → 200. Rate limit spec: burst → 429. |
| 10 | **DST transition handling** | Slot at 2:00 AM on fall-back day is ambiguous. Stored as UTC but local time is ambiguous. | Store UTC + IANA timezone identifier. UI converts via `tzdb`. For ambiguous local times, show both possibilities with disambiguation prompt. | Add a model spec: create slot at ambiguous time, assert both offsets are handled. |
| 11 | **Health check is shallow** | `/health` returns 200 if PG is up. Does not catch slow queries (8s latency). | Add `/health/ready`: sample query + p95 latency check against SLO. Kubernetes ready probe removes pod before users feel it. | Request spec: mock slow query, assert `/health/ready` returns 503. |
| 12 | **No outbox pattern for notifications** | Sidekiq crashes after booking commits but before job enqueues. User has no confirmation. No recovery. | Outbox table: write notification job to `outbox` in same DB transaction as booking. Poller reads outbox and enqueues to Sidekiq. Survives Sidekiq downtime. | Add outbox model + poller job spec: assert job is replayed after simulated Sidekiq failure. |

---

## Acceptance Criteria

- [ ] All P0 migrations run: `rails db:migrate` (0 failures)
- [ ] Full test suite: `bundle exec rspec` (0 failures, coverage maintained)
- [ ] P0 specs added: minimum 1 per gap, ideally concurrency/property-based where applicable
- [ ] `docker-compose up --build` boots cleanly
- [ ] k6 scripts pass: `concurrency.js`, `idempotency.js`, `multi-tenant.js`
- [ ] `QA_FIXES.md` created at repo root with: found / fixed / planned sections
- [ ] P1 items documented in `QA_FIXES.md` with production paths (no code required for P1 unless time permits)

---

## Constraints

- No new gem dependencies
- Keep pessimistic locking strategy unchanged
- All changes backward-compatible with existing seed data
- Follow existing conventions: service objects, thin controllers, Blueprinter serializers
- All new code has RSpec coverage

---

## Priority Order (Execution Sequence)

1. **P0.1** — DB unique constraint on `slot_id` (highest signal)
2. **P0.3** — Auth membership validation (security depth)
3. **P0.2** — Idempotency key unique index (data integrity)
4. **P0.4** — Reschedule atomicity test (correctness proof)
5. **P0.5** — Notification idempotency (operational safety)
6. **P1.7** — Booking limit concurrency test (if time remains)
7. **P1.8** — Foreign key constraints (if time remains)
8. **P1.6–12** — Document in `QA_FIXES.md` only

---

## P2: Known Gaps (Acknowledge, Don't Fix Tonight)

- Connection pool exhaustion under burst (PgBouncer path)
- No dead letter queue beyond Sidekiq retries
- No circuit breaker for OpenAI brief job
- No data retention / GDPR erasure workflow
- No deep health check (p95 latency probe)

**Talking points:** *"These are documented in `QA_FIXES.md` as Phase 2 production paths. I prioritized P0/P1 based on data integrity and security impact."*
