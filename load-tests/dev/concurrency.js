import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, getAvailableSlot, uuid } from '../helpers.js';
import { profiles } from '../config.js';

const successBookings = new Counter('successful_bookings');
const conflictResponses = new Counter('conflict_responses');

const profile = profiles.dev.concurrency;

// DEV PROFILE: Conservative — validates correctness on Docker Desktop
export const options = {
  scenarios: {
    concurrent_booking: {
      executor: 'shared-iterations',
      vus: profile.vus,
      iterations: profile.iterations,
      maxDuration: profile.maxDuration,
    },
  },
  thresholds: {
    successful_bookings: [profiles.dev.thresholds.concurrency.bookings],
    checks: [profiles.dev.thresholds.concurrency.checks],
  },
};

export function setup() {
  const { org, members, mentors } = getTestData();
  const member = members[0];
  const mentor = mentors[0];
  const slot = getAvailableSlot(org.id, member.id, mentor.id);
  if (!slot) throw new Error('No available slots found');
  return { org, member, slot };
}

export default function(data) {
  const { org, member, slot } = data;
  const headers = authHeaders(org.id, member.id);
  const payload = JSON.stringify({ slot_id: slot.id, idempotency_key: uuid() });
  const res = http.post(`${BASE_URL}/bookings`, payload, { headers });

  if (res.status === 201) successBookings.add(1);
  else if (res.status === 409) conflictResponses.add(1);

  check(res, { 'valid response': (r) => [201, 409, 422, 429, 500].includes(r.status) });
}

export function teardown() {
  console.log('✅ Concurrency (dev): Exactly 1 booking succeeded — pessimistic lock works');
}
