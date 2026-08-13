# QA Fixes — Found / Fixed / Planned

## Fixed (P0)

### 1. DB Unique Constraint on Active Bookings per Slot ✅
**Problem:** Pessimistic lock prevents double-booking at application layer, but no DB constraint as safety net.
**Fix:** Partial unique index: `unique: true, where: "status != 'cancelled'"` on `bookings.slot_id`.
**Migration:** `20260812120003_add_unique_index_bookings_active_slot.rb`
**Effect:** Even if a bug bypasses the service layer, the DB rejects duplicate active bookings.

### 2. Idempotency Key — Already Had Unique Index ✅
**Status:** `index_bookings_on_idempotency_key` is already `unique: true` in the schema.
**Verified:** Two identical requests → first creates, second hits unique constraint → returns existing booking.

### 3. Auth Membership Validation — Already Implemented ✅
**Status:** `Authenticatable` concern validates `Current.organization.users.find_by(id: user_id)`.
**Verified:** Mismatched user/org → 401. Missing headers → 401. Non-existent user → 401.

### 4. Reschedule Atomicity Under Failure ✅
**Problem:** Need proof that original booking survives if new slot is unavailable.
**Fix:** Added explicit spec: when new slot is already booked, original booking remains `confirmed` and original slot remains `booked`.
**Spec:** `spec/services/reschedule_service_spec.rb` — "preserves original booking when new slot is unavailable"

### 5. Foreign Key Constraints — Already Exist ✅
**Status:** `bookings` table has FKs on `slot_id`, `organization_id`, `member_id`.
**Verified via:** `ActiveRecord::Base.connection.foreign_keys('bookings')`

---

## Planned (P1 — Production Path Documented)

### 6. Cache Invalidation Race Condition
**Risk:** Read between commit and Redis invalidation shows stale slot.
**Current mitigation:** Frontend staleTime = 10s limits blast radius.
**Production fix:** CDC (Debezium/PgLogical) for async invalidation stream. Or Redis MULTI/EXEC for atomic invalidation.

### 7. Booking Limit Non-Atomic Check
**Risk:** Two threads check count simultaneously, both pass, exceed limit.
**Current mitigation:** `max_active_bookings` is nil (unlimited) in seed data.
**Production fix:** Advisory lock on `user_id` during booking, or denormalized `active_bookings_count` with DB CHECK constraint.

### 8. MCP Auth & Rate Limits
**Risk:** AI agent could loop `book_slot` without throttle.
**Current mitigation:** Same rack-attack rate limits apply to `/ai/*` endpoints.
**Production fix:** API key scopes (`mcp:read` vs `mcp:write`), per-tool rate limits, audit log table.

### 9. DST Ambiguous Time Handling
**Risk:** 2:00 AM on fall-back day has two possible UTC offsets.
**Current mitigation:** All slots stored as UTC. Frontend uses `Intl.DateTimeFormat` which handles DST correctly.
**Production fix:** For slot CREATION during ambiguous times, show disambiguation prompt.

### 10. Notification Job Idempotency
**Risk:** Sidekiq retry after SMTP timeout could send duplicate emails.
**Current mitigation:** In-app notifications are synchronous (not retried). Emails are idempotent in practice (same content, same timestamp).
**Production fix:** `notification_deliveries` table with unique constraint on `[booking_id, type, channel]`. Check before delivering.

### 11. Outbox Pattern for Guaranteed Delivery
**Risk:** Sidekiq crashes after booking commits but before job enqueues.
**Current mitigation:** In-app notification is synchronous (never lost). Only email delivery at risk.
**Production fix:** Write job to `outbox` table in same transaction as booking. Poller reads outbox and enqueues to Sidekiq.

### 12. Deep Health Check
**Risk:** `/health` returns 200 even if queries are slow (8s latency).
**Current:** Checks PG connectivity + Redis ping + Sidekiq process count.
**Production fix:** Add `/health/ready` with sample query latency check against SLO. Kubernetes readiness probe removes pod.

---

## Not Applicable (Kimi False Positives)

| Claim | Reality |
|-------|---------|
| "No unique index on idempotency_key" | ✅ Already exists (unique: true) |
| "No FK constraints" | ✅ Already exist (slot_id, organization_id, member_id) |
| "Auth allows impersonation" | ✅ Already validates user belongs to org |
