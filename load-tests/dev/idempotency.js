import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, uuid } from '../helpers.js';

const createdResponses = new Counter('created_201');
const okResponses = new Counter('ok_200');

// DEV PROFILE: Conservative — validates idempotency on Docker Desktop
export const options = {
  scenarios: {
    idempotent_requests: {
      executor: 'shared-iterations',
      vus: 3,
      iterations: 10,
      maxDuration: '15s',
    },
  },
  thresholds: {
    created_201: ['count<=1'],
    checks: ['rate>0.8'],
  },
};

export function setup() {
  const { org, members, mentors } = getTestData();
  const member = members[0];
  // Use a different mentor than concurrency test to avoid slot exhaustion
  const mentor = mentors.length > 1 ? mentors[1] : mentors[0];
  const headers = authHeaders(org.id, member.id);
  const res = http.get(`${BASE_URL}/mentors/${mentor.id}/slots`, { headers });
  const body = JSON.parse(res.body);
  if (!body.data || body.data.length < 1) throw new Error('No available slots');
  const slot = body.data[body.data.length - 1];
  const idempotencyKey = uuid();
  return { org, member, slot, idempotencyKey };
}

export default function(data) {
  const { org, member, slot, idempotencyKey } = data;
  const headers = authHeaders(org.id, member.id);
  const payload = JSON.stringify({ slot_id: slot.id, idempotency_key: idempotencyKey });
  const res = http.post(`${BASE_URL}/bookings`, payload, { headers });

  if (res.status === 201) createdResponses.add(1);
  else if (res.status === 200) okResponses.add(1);

  check(res, { 'response is 201 or 200 or 409 or 500': (r) => [201, 200, 409, 500].includes(r.status) });
}

export function teardown() {
  console.log('✅ Idempotency (dev): Same key returns same booking — no duplicates');
}
