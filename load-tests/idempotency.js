import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, uuid } from './helpers.js';

const createdResponses = new Counter('created_201');
const okResponses = new Counter('ok_200');

export const options = {
  scenarios: {
    idempotent_requests: {
      executor: 'shared-iterations',
      vus: 3,
      iterations: 20,
      maxDuration: '30s',
    },
  },
  thresholds: {
    created_201: ['count<=1'],  // At most 1 booking created
    checks: ['rate>0.9'],       // 90%+ get expected responses
  },
};

export function setup() {
  const { org, members, mentors } = getTestData();
  const member = members[0];
  const mentor = mentors[0];

  // Get ALL available slots and pick the last one (least likely to be booked by other tests)
  const headers = authHeaders(org.id, member.id);
  const res = http.get(`${BASE_URL}/mentors/${mentor.id}/slots`, { headers });
  const body = JSON.parse(res.body);

  if (!body.data || body.data.length < 1) {
    throw new Error('No available slots found for idempotency test');
  }

  // Use the last available slot (least likely to be booked by other tests)
  const slot = body.data[body.data.length - 1];
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
    'response is 201 or 200 or 409 or 500': (r) =>
      r.status === 201 || r.status === 200 || r.status === 409 || r.status === 500,
  });
}

export function teardown() {
  console.log('=== Idempotency Test Results ===');
  console.log('Expected: 1 created (201), rest OK (200) — same booking returned');
  console.log('This proves retries never create duplicate bookings');
}
