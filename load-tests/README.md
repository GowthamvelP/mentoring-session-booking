# Load Testing

Validates non-functional requirements (concurrency, idempotency, rate limiting, tenant isolation, performance) using [k6](https://k6.io/).

## Prerequisites

```bash
# Install k6 (macOS)
brew install k6

# Ensure the app is running
docker-compose up -d
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

# Production profile (with custom base URL)
k6 run -e BASE_URL=https://api.example.com/api/v1 production/concurrency.js
```

## Directory Structure

```
load-tests/
├── README.md              # This file
├── helpers.js             # Shared utilities (both profiles import from here)
├── dev/                   # Local Docker Desktop — conservative
│   ├── concurrency.js
│   ├── idempotency.js
│   ├── rate-limiting.js
│   ├── multi-tenant.js
│   └── booking-flow.js
├── production/            # Real infra — aggressive
│   ├── concurrency.js
│   ├── idempotency.js
│   ├── rate-limiting.js
│   ├── multi-tenant.js
│   └── booking-flow.js
├── run-dev.sh             # Runs dev suite
└── run-production.sh      # Runs production suite
```
