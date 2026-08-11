#!/bin/bash
set -e

echo "🔥 Running Load Tests — Non-Functional Requirements Validation"
echo "================================================================"
echo ""

# Check k6 is installed
if ! command -v k6 &> /dev/null; then
    echo "❌ k6 is not installed. Install with: brew install k6"
    exit 1
fi

# Check app is running
if ! curl -s http://localhost:3000/api/v1/health > /dev/null 2>&1; then
    echo "❌ Backend not running. Start with: docker-compose up -d"
    exit 1
fi

echo "✅ Backend is healthy"
echo ""

echo "--- Test 1: Concurrency (50 VUs, 1 slot) ---"
k6 run concurrency.js 2>&1 | tail -20
echo ""

echo "--- Test 2: Idempotency (100 requests, same key) ---"
k6 run idempotency.js 2>&1 | tail -20
echo ""

echo "--- Test 3: Rate Limiting (20 burst requests) ---"
k6 run rate-limiting.js 2>&1 | tail -20
echo ""

echo "--- Test 4: Multi-Tenant Isolation ---"
k6 run multi-tenant.js 2>&1 | tail -20
echo ""

echo "--- Test 5: Sustained Load (50 VUs, 30s) ---"
k6 run load-booking-flow.js 2>&1 | tail -25
echo ""

echo "================================================================"
echo "🏁 All load tests complete"
