import type { Booking } from '../../api/types'
import { SessionCard } from './SessionCard'

interface SessionListProps {
  bookings: Booking[]
  onCancel?: (bookingId: string) => void
  onReschedule?: (bookingId: string) => void
  actioningId?: string | null
}

export function SessionList({ bookings, onCancel, onReschedule, actioningId }: SessionListProps) {
  return (
    <div className="space-y-3">
      {bookings.map((booking) => (
        <SessionCard
          key={booking.id}
          booking={booking}
          onCancel={onCancel}
          onReschedule={onReschedule}
          isActioning={actioningId === booking.id}
        />
      ))}
    </div>
  )
}
