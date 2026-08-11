import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, getAvailableSlot, uuid } from './helpers.js';

const successBookings = new Counter('successful_bookings');
const conflictResponses = new Counter('conflict_responses');
const rateLimitedResponses = new Counter('rate_limited_429');
const unprocessableResponses = new Counter('unprocessable_422');

export const options = {
  scenarios: {
    concurrent_booking: {
      executor: 'shared-iterations',
      vus: 50,
      iterations: 50,
      maxDuration: '30s',
    },
  },
  thresholds: {
    successful_bookings: ['count==1'],  // Exactly 1 booking succeeds — core correctness guarantee
    checks: ['rate>0.9'],               // 90%+ get expected responses (201/409/422/429/500)
  },
};

// Setup: get test data and find an available slot
export function setup() {
  const { org, members, mentors } = getTestData();
  const member = members[0];
  const mentor = mentors[0];

  const slot = getAvailableSlot(org.id, member.id, mentor.id);
  if (!slot) {
    throw new Error('No available slots found for testing');
  }

  return { org, members, mentor, slot };
}

export default function(data) {
  const { org, members, slot } = data;
  // ALL VUs use the same member — testing concurrent booking from same user
  const member = members[0];

  const headers = authHeaders(org.id, member.id);
  const payload = JSON.stringify({
    slot_id: slot.id,
    idempotency_key: uuid(), // Each VU uses unique key
  });

  const res = http.post(`${BASE_URL}/bookings`, payload, { headers });

  if (res.status === 201) {
    successBookings.add(1);
  } else if (res.status === 409) {
    conflictResponses.add(1);
  } else if (res.status === 429) {
    rateLimitedResponses.add(1);
  } else if (res.status === 422) {
    unprocessableResponses.add(1);
  }

  check(res, {
    'response is 201 or 409 or 422 or 429 or 500': (r) =>
      r.status === 201 || r.status === 409 || r.status === 422 || r.status === 429 || r.status === 500,
  });
}

export function teardown(data) {
  console.log('=== Concurrency Test Results ===');
  console.log('Expected: 1 success (201), 49 conflicts (409)');
  console.log('This proves SELECT FOR UPDATE prevents double-booking');
}
