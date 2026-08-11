import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, getAvailableSlot, uuid } from './helpers.js';

const createdResponses = new Counter('created_201');
const okResponses = new Counter('ok_200');

export const options = {
  scenarios: {
    idempotent_requests: {
      executor: 'shared-iterations',
      vus: 10,
      iterations: 100,
      maxDuration: '30s',
    },
  },
  thresholds: {
    created_201: ['count==1'],  // Only first request creates
    ok_200: ['count==99'],      // All others return existing
  },
};

export function setup() {
  const { org, members, mentors } = getTestData();
  const member = members[0];
  const mentor = mentors[0];

  const slot = getAvailableSlot(org.id, member.id, mentor.id);
  if (!slot) {
    throw new Error('No available slots found');
  }

  // Fixed idempotency key — ALL requests use the same key
  const idempotencyKey = uuid();

  return { org, member, slot, idempotencyKey };
}

export default function(data) {
  const { org, member, slot, idempotencyKey } = data;

  const headers = authHeaders(org.id, member.id);
  const payload = JSON.stringify({
    slot_id: slot.id,
    idempotency_key: idempotencyKey, // SAME key for all requests
  });

  const res = http.post(`${BASE_URL}/bookings`, payload, { headers });

  if (res.status === 201) {
    createdResponses.add(1);
  } else if (res.status === 200) {
    okResponses.add(1);
  }

  check(res, {
    'response is 201 or 200': (r) => r.status === 201 || r.status === 200,
    'response has booking data': (r) => JSON.parse(r.body).data !== undefined,
  });
}

export function teardown() {
  console.log('=== Idempotency Test Results ===');
  console.log('Expected: 1 created (201), 99 OK (200) — same booking returned');
  console.log('This proves retries never create duplicate bookings');
}
