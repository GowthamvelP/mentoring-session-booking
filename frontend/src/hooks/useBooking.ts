import { useMutation, useQueryClient } from '@tanstack/react-query'
import { createBooking, cancelBooking, rescheduleBooking } from '../api/bookings'
import { QUERY_KEYS } from '../lib/constants'
import { generateIdempotencyKey } from '../lib/idempotency'

export function useCreateBooking() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (slotId: string) => createBooking(slotId, generateIdempotencyKey()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.sessions })
    },
  })
}

export function useCancelBooking() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (bookingId: string) => cancelBooking(bookingId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.sessions })
    },
  })
}

export function useRescheduleBooking() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ bookingId, newSlotId }: { bookingId: string; newSlotId: string }) =>
      rescheduleBooking(bookingId, newSlotId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.sessions })
    },
  })
}
