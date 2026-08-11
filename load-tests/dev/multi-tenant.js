import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL, authHeaders, getTestData } from '../helpers.js';

// DEV PROFILE: Conservative — validates tenant isolation on Docker Desktop
export const options = {
  scenarios: {
    tenant_isolation: {
      executor: 'shared-iterations',
      vus: 3,
      iterations: 10,
      maxDuration: '10s',
    },
  },
  thresholds: {
    checks: ['rate>0.9'],
  },
};

export function setup() {
  const orgsRes = http.get(`${BASE_URL}/organizations`);
  const orgs = JSON.parse(orgsRes.body);
  if (orgs.length < 2) throw new Error('Need 2+ orgs');
  const org1 = orgs[0];
  const org2 = orgs[1];
  const users1 = JSON.parse(http.get(`${BASE_URL}/organizations/${org1.id}/users`).body);
  const users2 = JSON.parse(http.get(`${BASE_URL}/organizations/${org2.id}/users`).body);
  return { org1, org2, user1: users1[0], user2: users2[0] };
}

export default function(data) {
  const { org1, org2, user1, user2 } = data;
  // Mismatched user/org should get 401
  const mismatchHeaders = authHeaders(org2.id, user1.id);
  const res = http.get(`${BASE_URL}/mentors`, { headers: mismatchHeaders });
  check(res, { 'mismatched user/org returns 401': (r) => r.status === 401 });
}

export function teardown() {
  console.log('✅ Tenant isolation (dev): Cross-org access rejected');
}
