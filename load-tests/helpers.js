import http from 'k6/http';

export const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000/api/v1';

// Get test data from seed (orgs and users)
export function getTestData() {
  const orgsRes = http.get(`${BASE_URL}/organizations`);
  const orgs = JSON.parse(orgsRes.body);

  if (!orgs || orgs.length === 0) {
    throw new Error('No organizations found — run docker-compose up first');
  }

  const org = orgs[0];
  const usersRes = http.get(`${BASE_URL}/organizations/${org.id}/users`);
  const users = JSON.parse(usersRes.body);

  const members = users.filter(u => u.role === 'member');
  const mentors = users.filter(u => u.role === 'mentor');

  return { org, members, mentors };
}

export function authHeaders(orgId, userId) {
  return {
    'Content-Type': 'application/json',
    'X-Org-Id': orgId,
    'X-User-Id': userId,
  };
}

export function getAvailableSlot(orgId, userId, mentorId) {
  const headers = authHeaders(orgId, userId);
  const res = http.get(`${BASE_URL}/mentors/${mentorId}/slots`, { headers });
  const body = JSON.parse(res.body);

  if (body.data && body.data.length > 0) {
    return body.data[0];
  }
  return null;
}

export function uuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}
