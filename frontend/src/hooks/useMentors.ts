import { useQuery } from '@tanstack/react-query'
import { getMentors } from '../api/mentors'
import { QUERY_KEYS, STALE_TIMES } from '../lib/constants'

export function useMentors(page = 1) {
  return useQuery({
    queryKey: [...QUERY_KEYS.mentors, page],
    queryFn: () => getMentors(page),
    staleTime: STALE_TIMES.mentors,
  })
}
