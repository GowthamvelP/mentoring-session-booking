import { useQuery } from '@tanstack/react-query'
import { getMySessions, getMyMentorSessions } from '../api/sessions'
import { QUERY_KEYS, STALE_TIMES } from '../lib/constants'

export function useMySessions(page = 1) {
  return useQuery({
    queryKey: [...QUERY_KEYS.sessions, page],
    queryFn: () => getMySessions(page),
    staleTime: STALE_TIMES.sessions,
  })
}

export function useMyMentorSessions(page = 1) {
  return useQuery({
    queryKey: [...QUERY_KEYS.mentorSessions, page],
    queryFn: () => getMyMentorSessions(page),
    staleTime: STALE_TIMES.sessions,
  })
}
