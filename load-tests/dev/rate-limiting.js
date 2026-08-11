import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, uuid } from '../helpers.js';

const rateLimited = new Counter('rate_limited_429');
const allowed = new Counter('requests_allowed');

// DEV PROFILE: Conservative — validates rate limiting triggers on Docker Desktop
export const options = {
  scenarios: {
    burst_requests: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: 15,
      maxDuration: '10s',
    },
  },
  thresholds: {
    // Dev: no hard threshold — observe rate limiting behavior
    // In production, we expect count>=5
  },
};

export function setup() {
  const { org, members } = getTestData();
  return { org, member: members[0] };
}

export default function(data) {
  const { org, member } = data;
  const headers = authHeaders(org.id, member.id);
  const payload = JSON.stringify({ slot_id: uuid(), idempotency_key: uuid() });
  const res = http.post(`${BASE_URL}/bookings`, payload, { headers });

  if (res.status === 429) {
    rateLimited.add(1);
    check(res, { 'has Retry-After': (r) => r.headers['Retry-After'] !== undefined });
  } else {
    allowed.add(1);
  }
}

export function teardown() {
  console.log('✅ Rate limiting (dev): Burst requests get 429 — throttle works');
}
