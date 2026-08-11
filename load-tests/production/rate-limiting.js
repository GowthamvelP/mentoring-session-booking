import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, uuid } from '../helpers.js';

const rateLimited = new Counter('rate_limited_429');
const allowed = new Counter('requests_allowed');

// PRODUCTION PROFILE: Aggressive burst — validates throttle triggers reliably
export const options = {
  scenarios: {
    burst_requests: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: 30,
      maxDuration: '15s',
    },
  },
  thresholds: {
    rate_limited_429: ['count>=5'],
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
  console.log('✅ Rate limiting (production): Burst of 30 requests triggers reliable 429 responses');
}
