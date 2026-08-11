import { useQuery } from '@tanstack/react-query'
import { apiClient } from '../api/client'
import { QUERY_KEYS, STALE_TIMES } from '../lib/constants'
import type { Slot } from '../api/types'

async function getMentorSlots(mentorId: string, startDate: string, endDate: string): Promise<Slot[]> {
  const { data } = await apiClient.get(`/mentors/${mentorId}/slots`, {
    params: { start_date: startDate, end_date: endDate },
  })
  return data
}

export function useSlots(mentorId: string, startDate: string, endDate: string) {
  return useQuery({
    queryKey: [...QUERY_KEYS.slots(mentorId), startDate, endDate],
    queryFn: () => getMentorSlots(mentorId, startDate, endDate),
    staleTime: STALE_TIMES.slots,
    enabled: !!mentorId,
  })
}
