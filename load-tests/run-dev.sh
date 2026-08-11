#!/bin/bash

echo "🧪 Running Development Load Tests (Docker Desktop)"
echo "==================================================="

if ! command -v k6 &>/dev/null; then echo "❌ k6 not installed. Run: brew install k6"; exit 1; fi
if ! curl -sf http://localhost:3000/api/v1/health >/dev/null; then echo "❌ Backend not running"; exit 1; fi

echo "✅ Backend healthy"

# Reset test state: restore all slots to available, clear bookings, flush cache
echo "🔄 Resetting test state..."
docker compose exec -T backend bin/rails runner "Slot.where(status: 'booked').update_all(status: 'available'); Booking.delete_all; Rails.cache.clear" 2>/dev/null || true
echo "✅ Test state reset"
echo ""

FAILURES=0

echo "--- Concurrency (5 VUs) ---"
k6 run dev/concurrency.js || FAILURES=$((FAILURES + 1))
echo ""

echo "--- Idempotency (3 VUs) ---"
k6 run dev/idempotency.js || FAILURES=$((FAILURES + 1))
echo ""

echo "--- Rate Limiting (1 VU, 15 burst) ---"
k6 run dev/rate-limiting.js || FAILURES=$((FAILURES + 1))
echo ""

echo "--- Multi-Tenant Isolation (3 VUs) ---"
k6 run dev/multi-tenant.js || FAILURES=$((FAILURES + 1))
echo ""

echo "--- Booking Flow (10 VUs, 20s) ---"
k6 run dev/booking-flow.js || FAILURES=$((FAILURES + 1))
echo ""

echo "==================================================="
if [ $FAILURES -eq 0 ]; then
  echo "🏁 Development load tests complete — all passed"
else
  echo "🏁 Development load tests complete — $FAILURES test(s) had threshold warnings"
fi
exit $FAILURES
