import type { Booking } from '../../api/types'
import { Card } from '../ui/Card'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'

interface SessionCardProps {
  booking: Booking
  onCancel?: (bookingId: string) => void
  onReschedule?: (bookingId: string) => void
  isActioning?: boolean
}

export function SessionCard({ booking, onCancel, onReschedule, isActioning = false }: SessionCardProps) {
  const statusVariant = {
    confirmed: 'success' as const,
    cancelled: 'danger' as const,
    completed: 'default' as const,
  }

  const startTime = new Date(booking.slot.start_time).toLocaleString()

  return (
    <Card>
      <div className="flex items-center justify-between">
        <div>
          <h4 className="font-medium text-text">{booking.mentor_name}</h4>
          <p className="mt-1 text-sm text-text-muted">{startTime}</p>
        </div>
        <Badge variant={statusVariant[booking.status]}>{booking.status}</Badge>
      </div>
      {booking.status === 'confirmed' && (
        <div className="mt-4 flex gap-2">
          {onReschedule && (
            <Button size="sm" variant="secondary" onClick={() => onReschedule(booking.id)} disabled={isActioning}>
              Reschedule
            </Button>
          )}
          {onCancel && (
            <Button size="sm" variant="danger" onClick={() => onCancel(booking.id)} disabled={isActioning}>
              {isActioning ? 'Cancelling...' : 'Cancel'}
            </Button>
          )}
        </div>
      )}
    </Card>
  )
}
