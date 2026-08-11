import { useQuery } from '@tanstack/react-query'
import { getMentors } from '../api/mentors'
import { QUERY_KEYS, STALE_TIMES } from '../lib/constants'

export function useMentors(page = 1, search?: string) {
  return useQuery({
    queryKey: [...QUERY_KEYS.mentors, page, search || ''],
    queryFn: () => getMentors(page, search),
    staleTime: STALE_TIMES.mentors,
  })
}
