import apiClient from './client'
import type { Booking } from './types'

export async function createBooking(slotId: string, idempotencyKey: string, timezone?: string): Promise<Booking> {
  const { data } = await apiClient.post('/bookings', {
    slot_id: slotId,
    idempotency_key: idempotencyKey,
    timezone: timezone,
  })
  return data.data ?? data
}

export async function cancelBooking(bookingId: string): Promise<Booking> {
  const { data } = await apiClient.patch(`/bookings/${bookingId}/cancel`)
  return data.data ?? data
}

export async function rescheduleBooking(bookingId: string, newSlotId: string): Promise<Booking> {
  const { data } = await apiClient.post(`/bookings/${bookingId}/reschedule`, {
    new_slot_id: newSlotId,
  })
  return data.data ?? data
}
