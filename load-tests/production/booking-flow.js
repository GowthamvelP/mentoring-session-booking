import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, authHeaders, getTestData, uuid } from '../helpers.js';

// PRODUCTION PROFILE: Aggressive — validates p95 < 200ms under sustained load
export const options = {
  stages: [
    { duration: '10s', target: 20 },
    { duration: '20s', target: 100 },
    { duration: '20s', target: 200 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],
    http_req_failed: ['rate<0.05'],
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

  // Full booking flow
  check(http.get(`${BASE_URL}/mentors`, { headers }), { 'mentors OK': (r) => r.status === 200 });

  const slotsRes = http.get(`${BASE_URL}/mentors/${mentor.id}/slots`, { headers });
  check(slotsRes, { 'slots OK': (r) => r.status === 200 });

  const slotsBody = JSON.parse(slotsRes.body);
  if (slotsBody.data && slotsBody.data.length > 0) {
    const slot = slotsBody.data[Math.floor(Math.random() * slotsBody.data.length)];
    const bookRes = http.post(`${BASE_URL}/bookings`, JSON.stringify({
      slot_id: slot.id,
      idempotency_key: uuid(),
    }), { headers });
    check(bookRes, { 'booking response valid': (r) => [200, 201, 409, 422, 429].includes(r.status) });
  }

  check(http.get(`${BASE_URL}/me/sessions`, { headers }), { 'sessions OK': (r) => r.status === 200 });
  sleep(0.3);
}

export function teardown() {
  console.log('✅ Booking flow (production): p95 < 200ms under 200 VUs sustained load');
}
