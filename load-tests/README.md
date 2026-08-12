# Load Testing

Validates non-functional requirements (concurrency, idempotency, rate limiting, tenant isolation, performance, reschedule safety) using [k6](https://k6.io/).

## Prerequisites

```bash
# Install k6 (macOS)
brew install k6

# Ensure the app is running
docker compose up -d
```

## Development Profile (Docker Desktop)

Conservative parameters tuned for local Docker (Puma single mode, 3 threads).
Validates **correctness** — not scale.

```bash
cd load-tests
./run-dev.sh
```

| Test | VUs | Iterations | Validates |
|------|-----|-----------|-----------|
| concurrency | 5 | 5 | Exactly 1 booking under concurrent load |
| idempotency | 3 | 10 | Same key never creates duplicates |
| rate-limiting | 1 | 15 | Burst triggers 429 |
| multi-tenant | 3 | 10 | Cross-org access rejected |
| booking-flow | 10 | 20s | Full flow p95 < 1000ms |
| reschedule-concurrency | 5 | 5 | At most 1 reschedule to same slot succeeds |

## Production Profile (Real Infrastructure)

Aggressive parameters for multi-worker Puma on ECS/production.
Validates **performance + correctness** under sustained load.

```bash
# Against local (default)
./run-production.sh

# Against deployed environment
BASE_URL=https://api.example.com/api/v1 ./run-production.sh
```

| Test | VUs | Iterations | Validates |
|------|-----|-----------|-----------|
| concurrency | 100 | 100 | Lock correctness at scale |
| idempotency | 50 | 500 | Deduplication under heavy load |
| rate-limiting | 1 | 30 | Throttle triggers reliably |
| multi-tenant | 20 | 100 | Isolation at scale |
| booking-flow | 200 | 60s | p95 < 200ms, <5% error rate |

## Run Individual Tests

```bash
# Dev profile
k6 run dev/concurrency.js
k6 run dev/idempotency.js
k6 run dev/rate-limiting.js
k6 run dev/multi-tenant.js
k6 run dev/booking-flow.js
k6 run dev/reschedule-concurrency.js

# Production profile (with custom base URL)
k6 run -e BASE_URL=https://api.example.com/api/v1 production/concurrency.js
```

## Directory Structure

```
load-tests/
├── README.md                      # This file
├── config.js                      # Centralized configuration (thresholds, VUs, durations)
├── helpers.js                     # Shared utilities (auth headers, test data, slot helpers)
├── dev/                           # Local Docker Desktop — conservative
│   ├── concurrency.js             # Pessimistic lock correctness
│   ├── idempotency.js             # Deduplication key enforcement
│   ├── rate-limiting.js           # Rack::Attack throttle
│   ├── multi-tenant.js            # Cross-org isolation
│   ├── booking-flow.js            # End-to-end performance
│   └── reschedule-concurrency.js  # Atomic reschedule safety
├── production/                    # Real infra — aggressive
│   ├── concurrency.js
│   ├── idempotency.js
│   ├── rate-limiting.js
│   ├── multi-tenant.js
│   └── booking-flow.js
├── run-dev.sh                     # Runs full dev suite (6 scenarios)
└── run-production.sh              # Runs full production suite (5 scenarios)
```

## What Each Test Proves

### Concurrency (Pessimistic Lock)
5 virtual users simultaneously book the **same slot**. Only 1 succeeds (201), others get 409 Conflict. Proves `SELECT FOR UPDATE` prevents double-booking.

### Idempotency
10 requests with the **same idempotency key**. First creates (201), subsequent return the existing booking (200). Never creates duplicates.

### Rate Limiting
15 rapid-fire requests from 1 VU. First ~10 pass (200), then rack-attack triggers 429 Too Many Requests.

### Multi-Tenant Isolation
Requests with mismatched user/org headers. Backend rejects with 401 Unauthorized. Proves tenant isolation at the API layer.

### Booking Flow (Performance)
10 VUs sustain 20 seconds of full booking cycles (list mentors → get slots → book). Validates p95 < 1000ms response time and <30% failure rate.

### Reschedule Concurrency
Multiple users simultaneously attempt to reschedule into the **same available slot**. At most 1 succeeds. Proves atomic reschedule with pessimistic locking on the target slot.
