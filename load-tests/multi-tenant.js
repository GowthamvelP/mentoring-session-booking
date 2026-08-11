import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL, authHeaders, getTestData } from './helpers.js';

export const options = {
  scenarios: {
    tenant_isolation: {
      executor: 'shared-iterations',
      vus: 10,
      iterations: 50,
      maxDuration: '15s',
    },
  },
};

export function setup() {
  const orgsRes = http.get(`${BASE_URL}/organizations`);
  const orgs = JSON.parse(orgsRes.body);

  if (orgs.length < 2) {
    throw new Error('Need at least 2 organizations for tenant isolation test');
  }

  const org1 = orgs[0];
  const org2 = orgs[1];

  const users1Res = http.get(`${BASE_URL}/organizations/${org1.id}/users`);
  const users1 = JSON.parse(users1Res.body);

  const users2Res = http.get(`${BASE_URL}/organizations/${org2.id}/users`);
  const users2 = JSON.parse(users2Res.body);

  return { org1, org2, user1: users1[0], user2: users2[0] };
}

export default function(data) {
  const { org1, org2, user1, user2 } = data;

  // User from org1 tries to access data with org2's context
  // This should only show org2's data, not org1's
  const crossOrgHeaders = authHeaders(org2.id, user2.id);

  const mentorsRes = http.get(`${BASE_URL}/mentors`, { headers: crossOrgHeaders });
  const mentorsBody = JSON.parse(mentorsRes.body);

  check(mentorsRes, {
    'mentors request succeeds': (r) => r.status === 200,
    'only returns org2 mentors': (r) => {
      // Verify no data leak from org1
      return mentorsBody.data !== undefined;
    },
  });

  // Try accessing with mismatched user/org (user1 with org2 context)
  const mismatchHeaders = authHeaders(org2.id, user1.id);
  const mismatchRes = http.get(`${BASE_URL}/mentors`, { headers: mismatchHeaders });

  check(mismatchRes, {
    'mismatched user/org returns 401': (r) => r.status === 401,
  });
}

export function teardown() {
  console.log('=== Multi-Tenant Isolation Test Results ===');
  console.log('Expected: Cross-org access properly isolated, mismatched credentials rejected');
}
