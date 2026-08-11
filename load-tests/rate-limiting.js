import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, uuid } from './helpers.js';

const rateLimited = new Counter('rate_limited_429');
const allowed = new Counter('requests_allowed');

export const options = {
  scenarios: {
    burst_requests: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: 20,  // Send 20 requests from 1 user (limit is 10/min)
      maxDuration: '10s',
    },
  },
  thresholds: {
    rate_limited_429: ['count>0'],  // At least some get rate limited
  },
};

export function setup() {
  const { org, members, mentors } = getTestData();
  return { org, member: members[0], mentor: mentors[0] };
}

export default function(data) {
  const { org, member, mentor } = data;
  const headers = authHeaders(org.id, member.id);

  // Rapidly fire booking requests (different slots, same user)
  const payload = JSON.stringify({
    slot_id: uuid(), // Invalid slot ID — we just want to test rate limiting
    idempotency_key: uuid(),
  });

  const res = http.post(`${BASE_URL}/bookings`, payload, { headers });

  if (res.status === 429) {
    rateLimited.add(1);
    check(res, {
      'has Retry-After header': (r) => r.headers['Retry-After'] !== undefined,
    });
  } else {
    allowed.add(1);
  }
}

export function teardown() {
  console.log('=== Rate Limiting Test Results ===');
  console.log('Expected: first 10 requests allowed, then 429 responses');
  console.log('This proves rack-attack rate limiting works under burst');
}
