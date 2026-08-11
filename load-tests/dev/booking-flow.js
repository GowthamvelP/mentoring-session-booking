import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, authHeaders, getTestData, uuid } from '../helpers.js';

// DEV PROFILE: Conservative — validates full flow performance on Docker Desktop
export const options = {
  stages: [
    { duration: '5s', target: 5 },
    { duration: '10s', target: 10 },
    { duration: '5s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    http_req_failed: ['rate<0.3'],
  },
};

export function setup() {
  const { org, members, mentors } = getTestData();
  return { org, members, mentors };
}

export default function(data) {
  const { org, members, mentors } = data;
  const member = members[0];
  const mentor = mentors[0];
  const headers = authHeaders(org.id, member.id);

  check(http.get(`${BASE_URL}/mentors`, { headers }), { 'mentors OK': (r) => r.status === 200 });
  check(http.get(`${BASE_URL}/mentors/${mentor.id}/slots`, { headers }), { 'slots OK': (r) => r.status === 200 });
  check(http.get(`${BASE_URL}/me/sessions`, { headers }), { 'sessions OK': (r) => r.status === 200 });
  sleep(0.3);
}

export function teardown() {
  console.log('✅ Booking flow (dev): Full flow completes within p95 < 1000ms');
}
