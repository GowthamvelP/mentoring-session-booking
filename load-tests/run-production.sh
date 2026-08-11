#!/bin/bash
set -e

BASE_URL=${BASE_URL:-"http://localhost:3000/api/v1"}

echo "🔥 Running Production Load Tests"
echo "================================================="
echo "Target: $BASE_URL"

if ! command -v k6 &>/dev/null; then echo "❌ k6 not installed"; exit 1; fi
if ! curl -sf "$BASE_URL/health" >/dev/null; then echo "❌ Backend not reachable at $BASE_URL"; exit 1; fi

echo "✅ Backend healthy"
echo ""

echo "🔄 Resetting test state..."
if [ "$BASE_URL" = "http://localhost:3000/api/v1" ]; then
  docker compose exec -T backend bin/rails runner "Slot.where(status: 'booked').update_all(status: 'available'); Booking.delete_all; Rails.cache.clear" 2>/dev/null || true
  echo "✅ Test state reset (local mode)"
else
  echo "⚠️  Skipping state reset (remote target — ensure clean state manually)"
fi
echo ""

echo "--- Concurrency (100 VUs) ---"
k6 run -e BASE_URL=$BASE_URL production/concurrency.js
echo ""

echo "--- Idempotency (50 VUs, 500 requests) ---"
k6 run -e BASE_URL=$BASE_URL production/idempotency.js
echo ""

echo "--- Rate Limiting (30 burst) ---"
k6 run -e BASE_URL=$BASE_URL production/rate-limiting.js
echo ""

echo "--- Multi-Tenant Isolation (20 VUs) ---"
k6 run -e BASE_URL=$BASE_URL production/multi-tenant.js
echo ""

echo "--- Sustained Load (200 VUs, 60s) ---"
k6 run -e BASE_URL=$BASE_URL production/booking-flow.js
echo ""

echo "================================================="
echo "🏁 Production load tests complete"
