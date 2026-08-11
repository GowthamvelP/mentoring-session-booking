export const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000/api/v1'

export const QUERY_KEYS = {
  organizations: ['organizations'] as const,
  mentors: ['mentors'] as const,
  slots: (mentorId: string) => ['slots', mentorId] as const,
  sessions: ['sessions'] as const,
  mentorSessions: ['mentorSessions'] as const,
}

export const STALE_TIMES = {
  organizations: Infinity,
  mentors: 5 * 60 * 1000,
  slots: 30 * 1000,
  sessions: 60 * 1000,
}
