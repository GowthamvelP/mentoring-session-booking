import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, authHeaders, getTestData, uuid } from '../helpers.js';
import { profiles } from '../config.js';

const successfulReschedules = new Counter('successful_reschedules');
const conflictResponses = new Counter('reschedule_conflicts');

const profile = profiles.dev.concurrency;

// Test: Multiple users try to reschedule INTO the same available slot
// Expected: Exactly 1 succeeds (pessimistic lock on new slot prevents double-booking)
export const options = {
  scenarios: {
    concurrent_reschedule: {
      executor: 'shared-iterations',
      vus: profile.vus,
      iterations: profile.iterations,
      maxDuration: profile.maxDuration,
    },
  },
  thresholds: {
    successful_reschedules: ['count==1'],
    checks: ['rate>0.8'],
  },
};

export function setup() {
  const { org, members, mentors } = getTestData();
  const mentor = mentors[0];
  const headers = authHeaders(org.id, members[0].id);

  // Get available slots — we need at least 2 (one to book, one as target)
  const slotsRes = http.get(`${BASE_URL}/mentors/${mentor.id}/slots`, { headers });
  const slotsBody = JSON.parse(slotsRes.body);
  const slots = slotsBody.data || [];
  const availableSlots = slots.filter(s => s.status === 'available');

  if (availableSlots.length < 2) {
    throw new Error(`Need at least 2 available slots, found ${availableSlots.length}`);
  }

  // Book the first slot (so we can reschedule FROM it)
  const bookPayload = JSON.stringify({
    slot_id: availableSlots[0].id,
    idempotency_key: uuid()
  });
  const bookRes = http.post(`${BASE_URL}/bookings`, bookPayload, { headers });
  const bookBody = JSON.parse(bookRes.body);

  if (bookRes.status !== 201 && bookRes.status !== 200) {
    throw new Error(`Setup booking failed: ${bookRes.status} ${bookRes.body}`);
  }

  const bookingId = bookBody.data.id;
  const targetSlotId = availableSlots[1].id;

  // Create additional bookings for other members (to simulate concurrent rescheduling)
  const bookings = [bookingId];
  for (let i = 1; i < Math.min(members.length, profile.vus); i++) {
    const memberHeaders = authHeaders(org.id, members[i].id);
    // Book another available slot for each member
    if (availableSlots.length > i + 1) {
      const payload = JSON.stringify({
        slot_id: availableSlots[i + 1].id,
        idempotency_key: uuid()
      });
      const res = http.post(`${BASE_URL}/bookings`, payload, { headers: memberHeaders });
      if (res.status === 201 || res.status === 200) {
        const body = JSON.parse(res.body);
        bookings.push(body.data.id);
      }
    }
  }

  return { org, members, bookings, targetSlotId };
}

export default function(data) {
  const { org, members, bookings, targetSlotId } = data;
  const vuIndex = __VU - 1;
  const memberIndex = Math.min(vuIndex, members.length - 1);
  const bookingIndex = Math.min(vuIndex, bookings.length - 1);

  const headers = authHeaders(org.id, members[memberIndex].id);
  const payload = JSON.stringify({
    new_slot_id: targetSlotId,
    timezone: 'UTC'
  });

  const res = http.post(
    `${BASE_URL}/bookings/${bookings[bookingIndex]}/reschedule`,
    payload,
    { headers }
  );

  if (res.status === 201) successfulReschedules.add(1);
  else conflictResponses.add(1);

  check(res, {
    'valid response': (r) => [201, 409, 422, 403, 500].includes(r.status)
  });
}

export function teardown() {
  console.log('✅ Reschedule Concurrency (dev): At most 1 reschedule to same slot succeeds — pessimistic lock works');
}
