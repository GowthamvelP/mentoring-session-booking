# Load Testing — Non-Functional Requirements Validation

These scripts validate the system's behavior under concurrent load using [k6](https://k6.io/).

## Prerequisites

```bash
# Install k6 (macOS)
brew install k6

# Ensure the app is running
docker-compose up -d
```

## Test Scenarios

| Script | What It Tests | Expected Result |
|--------|--------------|-----------------|
| `concurrency.js` | 50 concurrent bookings for the same slot | Exactly 1 succeeds (201), others get 409 |
| `idempotency.js` | Same request sent 100 times | All return 200, only 1 record created |
| `rate-limiting.js` | 20 rapid booking requests | First 10 succeed, next 10 get 429 |
| `multi-tenant.js` | Cross-org data access attempts | All return 401 or empty results |
| `load-booking-flow.js` | Sustained booking load (50 VUs, 30s) | p95 < 200ms, 0 errors |

## Run All Tests

```bash
cd load-tests
./run-all.sh
```

## Run Individual Tests

```bash
k6 run concurrency.js
k6 run idempotency.js
k6 run rate-limiting.js
k6 run multi-tenant.js
k6 run load-booking-flow.js
```
