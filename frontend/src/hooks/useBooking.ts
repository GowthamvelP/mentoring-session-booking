import { useMutation, useQueryClient } from "@tanstack/react-query"
import { createBooking, cancelBooking, rescheduleBooking } from "../api/bookings"
import { QUERY_KEYS } from "../lib/constants"
import { generateIdempotencyKey } from "../lib/idempotency"
import type { Slot } from "../api/types"

export function useCreateBooking(mentorId?: string, timezone?: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (slotId: string) => createBooking(slotId, generateIdempotencyKey(), timezone),
    onMutate: async (slotId: string) => {
      if (!mentorId) return

      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: QUERY_KEYS.slots(mentorId) })

      // Snapshot previous state
      const previousSlots = queryClient.getQueriesData({ queryKey: QUERY_KEYS.slots(mentorId) })

      // Optimistically remove the slot from cache
      queryClient.setQueriesData<Slot[]>(
        { queryKey: QUERY_KEYS.slots(mentorId) },
        (old) => old?.filter((slot) => slot.id !== slotId),
      )

      return { previousSlots }
    },
    onError: (_err, _slotId, context) => {
      // Rollback on error
      if (context?.previousSlots) {
        for (const [queryKey, data] of context.previousSlots) {
          queryClient.setQueryData(queryKey, data)
        }
      }
    },
    onSettled: () => {
      // Always refetch slots and sessions after mutation settles
      if (mentorId) {
        queryClient.invalidateQueries({ queryKey: QUERY_KEYS.slots(mentorId) })
      }
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.sessions })
    },
  })
}

export function useCancelBooking() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (bookingId: string) => cancelBooking(bookingId),
    onSuccess: () => {
      // Invalidate sessions to reflect cancelled status
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.sessions })
      // Also invalidate ALL slots queries — the cancelled slot is now available again
      queryClient.invalidateQueries({ queryKey: ["slots"] })
    },
  })
}

export function useRescheduleBooking(timezone?: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ bookingId, newSlotId }: { bookingId: string; newSlotId: string }) =>
      rescheduleBooking(bookingId, newSlotId, timezone),
    onSuccess: () => {
      // Invalidate sessions to reflect the new booking
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.sessions })
      // Invalidate ALL slot queries — both the old slot (now available)
      // and new slot (now booked) may belong to any mentor
      queryClient.invalidateQueries({ queryKey: ["slots"] })
    },
  })
}
