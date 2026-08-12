export const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:3000/api/v1"

export const QUERY_KEYS = {
  organizations: ["organizations"] as const,
  mentors: ["mentors"] as const,
  slots: (mentorId: string) => ["slots", mentorId] as const,
  sessions: ["sessions"] as const,
  mentorSessions: ["mentorSessions"] as const,
  notifications: ["notifications"] as const,
}

export const STALE_TIMES = {
  organizations: Infinity,
  mentors: 5 * 60 * 1000,
  slots: 10 * 1000, // 10s — slots change frequently during booking
  sessions: 30 * 1000, // 30s — sessions update after booking/cancel/reschedule
  notifications: 15 * 1000, // 15s — poll for new notifications
}
