import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, authHeaders, getTestData, getAvailableSlot, uuid } from './helpers.js';

export const options = {
  stages: [
    { duration: '10s', target: 20 },   // Ramp up to 20 VUs
    { duration: '20s', target: 50 },   // Ramp to 50 VUs
    { duration: '10s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],    // 95% of requests under 500ms
    http_req_failed: ['rate<0.1'],       // Less than 10% failure rate
  },
};

export function setup() {
  const { org, members, mentors } = getTestData();
  return { org, members, mentors };
}

export default function(data) {
  const { org, members, mentors } = data;
  const member = members[__VU % members.length] || members[0];
  const mentor = mentors[__VU % mentors.length] || mentors[0];
  const headers = authHeaders(org.id, member.id);

  // Simulate a full booking flow
  // 1. List mentors
  const mentorsRes = http.get(`${BASE_URL}/mentors`, { headers });
  check(mentorsRes, { 'list mentors OK': (r) => r.status === 200 });

  // 2. Get slots
  const slotsRes = http.get(`${BASE_URL}/mentors/${mentor.id}/slots`, { headers });
  check(slotsRes, { 'get slots OK': (r) => r.status === 200 });

  // 3. Attempt booking (may fail with 409 if slot taken — that's OK)
  const slotsBody = JSON.parse(slotsRes.body);
  if (slotsBody.data && slotsBody.data.length > 0) {
    const slot = slotsBody.data[Math.floor(Math.random() * slotsBody.data.length)];
    const bookRes = http.post(`${BASE_URL}/bookings`, JSON.stringify({
      slot_id: slot.id,
      idempotency_key: uuid(),
    }), { headers });

    check(bookRes, {
      'booking response valid': (r) => [200, 201, 409, 422].includes(r.status),
    });
  }

  // 4. Check my sessions
  const sessionsRes = http.get(`${BASE_URL}/me/sessions`, { headers });
  check(sessionsRes, { 'sessions OK': (r) => r.status === 200 });

  sleep(0.5); // Simulate user think time
}

export function teardown() {
  console.log('=== Load Test Results ===');
  console.log('Expected: p95 < 500ms, error rate < 10%');
  console.log('This validates overall system performance under sustained load');
}
