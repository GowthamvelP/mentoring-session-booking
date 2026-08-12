# Production Scaling & Non-Functional Requirements Architecture

## Overview

This document describes how the mentoring session booking system would scale from a single-Docker MVP to a production deployment handling thousands of concurrent users. The current implementation proves **correctness** (ACID, idempotency, locking). This document addresses **scalability, availability, and partition tolerance**.

---

## System Characteristics

| Dimension | Profile | Implication |
|-----------|---------|-------------|
| **Read:Write Ratio** | 50:1 (browse slots >> book slots) | Read replica strategy, aggressive caching |
| **Consistency Requirement** | Strong for writes, eventual for reads | CP for bookings, AP for browsing |
| **Burst Pattern** | Predictable (Monday mornings, end-of-month) | Pre-scaled, queue-based absorption |
| **Tenant Count** | 100s of orgs, 1000s of users per org | Partition by org_id, connection pooling |
| **Latency SLA** | p95 < 200ms (reads), p95 < 500ms (writes) | Edge caching, optimized query paths |

---

## CAP Theorem Trade-offs

### Bookings (CP — Consistency + Partition Tolerance)
- **Why**: Double-booking is unacceptable. A booking must be globally consistent.
- **Implementation**: Pessimistic lock on primary database. Single source of truth.
- **Sacrifice**: Availability during network partitions (booking fails rather than duplicates).

### Slot Browsing (AP — Availability + Partition Tolerance)
- **Why**: Showing slightly stale availability is acceptable. Showing nothing is not.
- **Implementation**: Redis cache (10s TTL) + CDN edge cache. Serve stale if Redis is down.
- **Sacrifice**: Consistency — a slot may appear available for up to 10s after booking.

### Notifications (AP — Availability + Partition Tolerance)
- **Why**: Missing a notification temporarily is acceptable. Losing it permanently is not.
- **Implementation**: Synchronous DB write (durability) + eventual delivery (email via queue).
- **Sacrifice**: Real-time guarantee — delivery may lag under partition.

---

## Database Scaling Strategy

### Read Replicas (RDS Multi-AZ)

```
                    ┌─────────────────┐
                    │   Application   │
                    │   (Rails/Puma)  │
                    └───────┬─────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
     ┌────────▼────────┐       ┌──────────▼──────────┐
     │  Primary (RW)   │──────▶│  Replica (RO)       │
     │  Writes + Locks │ sync  │  Reads (slots, list) │
     │  (single AZ)    │       │  (multi-AZ)          │
     └─────────────────┘       └──────────────────────┘
```

**Rails Configuration** (Rails 6+ built-in):
```ruby
# config/database.yml
production:
  primary:
    url: <%= ENV['DATABASE_PRIMARY_URL'] %>
  replica:
    url: <%= ENV['DATABASE_REPLICA_URL'] %>
    replica: true

# Usage: automatic routing
class ApplicationRecord < ActiveRecord::Base
  connects_to database: { writing: :primary, reading: :replica }
end
```

**Read paths** (routed to replica): mentor list, slot browsing, session history, notifications
**Write paths** (always primary): booking creation, cancellation, reschedule, slot status updates

### Connection Pooling (PgBouncer)

```
Rails (100 Puma threads) → PgBouncer (20 connections) → PostgreSQL (max 100)
```

- **Why**: Each Rails process holds a connection per thread. With 10 containers × 10 threads = 100 connections. PgBouncer pools and multiplexes.
- **Mode**: Transaction pooling (connection returned after each transaction, not session).
- **Benefit**: 10x container scaling without hitting PostgreSQL `max_connections`.

### Table Partitioning (at scale)

```sql
-- Partition bookings by organization_id (range or hash)
CREATE TABLE bookings (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  ...
) PARTITION BY HASH (organization_id);

CREATE TABLE bookings_p0 PARTITION OF bookings FOR VALUES WITH (MODULUS 8, REMAINDER 0);
CREATE TABLE bookings_p1 PARTITION OF bookings FOR VALUES WITH (MODULUS 8, REMAINDER 1);
-- ... up to p7
```

- **Trigger**: When bookings table exceeds 10M rows or queries exceed 50ms p95
- **Benefit**: Query pruning — each org's data is physically separated, improving cache hit rates

---

## Horizontal Scaling (Kubernetes / ECS)

### Stateless Application Tier

```yaml
# Simplified K8s deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mentoring-api
spec:
  replicas: 5  # HPA scales 3-20 based on CPU/requests
  template:
    spec:
      containers:
        - name: rails
          resources:
            requests: { cpu: 500m, memory: 512Mi }
            limits: { cpu: 1000m, memory: 1Gi }
          env:
            - name: RAILS_MAX_THREADS
              value: "5"
            - name: WEB_CONCURRENCY
              value: "2"  # Puma workers (forked processes)
```

**Why stateless works**: 
- No session state (JWT/header auth)
- No file uploads (API-only)
- Redis handles shared state (cache, rate limits)
- PostgreSQL handles durable state (bookings, slots)

### Auto-Scaling Policy

| Metric | Scale Up | Scale Down | Cooldown |
|--------|----------|------------|----------|
| CPU > 70% | +2 pods | -1 pod | 3 min |
| Request latency p95 > 300ms | +3 pods | — | 5 min |
| Queue depth > 100 | +1 Sidekiq pod | -1 pod | 2 min |

---

## Burst Handling Strategy

### Problem: Monday 9 AM Booking Rush
All members in an org try to book popular mentors simultaneously. 50 people → 1 mentor → 5 available slots.

### Current Approach (Works at MVP Scale)
Pessimistic lock + 409 Conflict. 5 win, 45 retry or pick another slot. Sub-50ms per lock acquisition.

### Production Approach (10,000+ concurrent)

**Queue-Based Booking with Confirmation**:
```
Member clicks "Book" → Job enqueued with priority timestamp
                     → Immediate response: "Booking processing..."
                     → Worker processes in FIFO order
                     → Push notification: "Confirmed!" or "Slot taken, here are alternatives"
```

**Benefits**:
- No lock contention on the web tier (requests return in <50ms)
- Fairness: first-come-first-served via queue ordering
- Graceful degradation: queue absorbs burst, workers drain at steady rate
- User experience: "Processing..." is acceptable for high-demand slots

**Implementation**:
```ruby
# BookingService returns immediately with "pending" status
class AsyncBookingService
  def call
    BookingRequest.create!(member:, slot:, requested_at: Time.current)
    BookingProcessorJob.perform_later(booking_request.id)
    { status: :pending, message: "Processing your booking..." }
  end
end

# Worker processes sequentially — no lock contention
class BookingProcessorJob
  def perform(request_id)
    request = BookingRequest.find(request_id)
    result = BookingService.call(slot_id: request.slot_id, ...)
    
    if result[:success]
      NotificationService.booking_confirmed(result[:booking])
    else
      NotificationService.booking_failed(request, alternatives: find_alternatives(request))
    end
  end
end
```

---

## Caching Strategy (Multi-Layer)

```
Browser (TanStack Query, 10s stale)
    ↓ miss
CloudFront Edge (10s TTL for slot listings)
    ↓ miss
Redis (Rails.cache, 300s TTL, pattern invalidation)
    ↓ miss
PostgreSQL (read replica for GET, primary for POST)
```

### Cache Invalidation Guarantees

| Event | Invalidation | Propagation Time |
|-------|-------------|-----------------|
| Booking created | Redis: `slots:{mentor_id}:*` deleted | Immediate |
| Booking cancelled | Redis: `slots:{mentor_id}:*` deleted | Immediate |
| Reschedule | Redis: both mentor keys deleted | Immediate |
| CDN | Edge TTL expires (10s max stale) | 10 seconds |
| Frontend | `invalidateQueries` → immediate refetch | 0ms (triggering user) |

### Circuit Breaker (Redis Failure)

```ruby
# If Redis is down, bypass cache — serve from DB directly
class SlotService
  def available_slots(mentor_id, date_range)
    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      Slot.where(mentor_id:, status: :available, start_time: date_range)
    end
  rescue Redis::CannotConnectError, Redis::TimeoutError
    # Circuit breaker: serve from DB, log degradation
    Rails.logger.warn("Redis unavailable — serving slots from database")
    Slot.where(mentor_id:, status: :available, start_time: date_range)
  end
end
```

---

## Network Resilience

### Retry Strategy (Client-Side)

| Layer | Retry Policy | Idempotency |
|-------|-------------|-------------|
| Frontend → Backend | TanStack Query retry (3x, exponential) | Idempotency key prevents duplicates |
| Backend → Redis | `connection_pool` with 3 retries | Read cache misses are safe to retry |
| Backend → PostgreSQL | ActiveRecord reconnect (built-in) | Transaction rollback is safe |
| Sidekiq → External APIs | 5 retries, exponential backoff | Job idempotency (check before act) |

### Timeout Budget

```
Total request budget: 500ms
├── Network (client → LB): 20ms
├── LB → Container: 5ms
├── Rails middleware: 10ms
├── Controller + Service: 50ms
├── Database query: 30ms (p95)
├── Redis cache: 5ms
└── Response serialization: 10ms
    Buffer: 370ms (for GC pauses, cold JIT, connection acquisition)
```

### Health Check Cascade

```
ALB → /api/v1/health
        ├── PostgreSQL: SELECT 1 (5s timeout)
        ├── Redis: PING (2s timeout)
        └── Sidekiq: process count > 0

If ANY check fails:
  → Container marked unhealthy
  → ALB stops routing traffic
  → ECS replaces container (self-healing)
```

---

## Availability Architecture

### Multi-AZ Deployment (AWS)

```
Region: us-east-1
├── AZ-a: 2x API pods, 1x Sidekiq pod, RDS Primary
├── AZ-b: 2x API pods, 1x Sidekiq pod, RDS Replica (sync)
└── AZ-c: 1x API pod (standby), RDS Replica (async, disaster recovery)

Redis: ElastiCache Multi-AZ with automatic failover
Queue: Redis Sentinel or ElastiCache cluster mode
```

**RTO (Recovery Time Objective)**: < 60 seconds (ECS container replacement)
**RPO (Recovery Point Objective)**: 0 (synchronous replication to AZ-b)

---

## Monitoring & Alerting (Production)

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| API p95 latency | > 300ms | > 1000ms | Scale up + investigate |
| Error rate (5xx) | > 1% | > 5% | Page on-call |
| Database connections | > 70% | > 90% | Scale PgBouncer pool |
| Redis memory | > 70% | > 85% | Eviction policy check |
| Sidekiq queue depth | > 50 | > 200 | Scale workers |
| Failed jobs (dead set) | > 0 | > 10 | Investigate + alert |
| Disk IOPS (RDS) | > 3000 | > 5000 | Upgrade instance class |

### Incident Response Workflow

```
1. Alert fires (PagerDuty/Opsgenie)
2. Check Grafana dashboard (request rate, error rate, latency)
3. Correlate with deployment timeline (was there a recent deploy?)
4. If deploy-related: kamal rollback
5. If load-related: scale up (kubectl scale / ECS desired count)
6. If data-related: grep logs by correlation_id
7. RCA within 24 hours, documented in incident log
```

---

## What's Implemented vs. Documented

| Capability | Status | Implementation |
|------------|--------|----------------|
| Pessimistic locking | ✅ Implemented | `SELECT FOR UPDATE` in transactions |
| Idempotency | ✅ Implemented | Unique constraint on `idempotency_key` |
| Rate limiting | ✅ Implemented | rack-attack (per-endpoint, Redis-backed) |
| Redis caching | ✅ Implemented | Cache-aside, pattern invalidation |
| Async processing | ✅ Implemented | Sidekiq weighted queues (critical/default/ai) |
| Multi-tenancy | ✅ Implemented | acts_as_tenant (query-level isolation) |
| Structured logging | ✅ Implemented | Lograge JSON + correlation IDs |
| Health checks | ✅ Implemented | PG + Redis + Sidekiq status |
| Read replicas | 📐 Documented | Rails `connects_to` with `replica: true` |
| Connection pooling | 📐 Documented | PgBouncer transaction mode |
| Horizontal scaling | 📐 Documented | K8s/ECS stateless deployment |
| Burst handling | 📐 Documented | Queue-based booking with async confirmation |
| CDN edge caching | 📐 Documented | CloudFront 10s TTL for slot listings |
| Circuit breakers | 📐 Documented | Redis failure → DB fallback |
| Multi-AZ HA | 📐 Documented | RDS sync replica, ElastiCache failover |
| Table partitioning | 📐 Documented | Hash partition by org_id |
| Auto-scaling | 📐 Documented | HPA on CPU + latency + queue depth |
