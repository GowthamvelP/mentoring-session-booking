import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, getAvailableSlot, uuid } from './helpers.js';

const successBookings = new Counter('successful_bookings');
const conflictResponses = new Counter('conflict_responses');

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
    successful_bookings: ['count==1'],   // Exactly 1 booking succeeds
    conflict_responses: ['count==49'],   // 49 get conflict
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
  // Each VU uses a different member but targets the SAME slot
  const memberIndex = __VU % members.length;
  const member = members[memberIndex] || members[0];

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
  }

  check(res, {
    'response is 201 or 409': (r) => r.status === 201 || r.status === 409,
  });
}

export function teardown(data) {
  console.log('=== Concurrency Test Results ===');
  console.log('Expected: 1 success (201), 49 conflicts (409)');
  console.log('This proves SELECT FOR UPDATE prevents double-booking');
}
