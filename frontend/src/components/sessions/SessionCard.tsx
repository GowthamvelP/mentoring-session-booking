import { memo } from 'react'
import { format, parseISO } from 'date-fns'
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

const statusConfig = {
  confirmed: { variant: 'success' as const, label: 'Confirmed' },
  cancelled: { variant: 'danger' as const, label: 'Cancelled' },
  completed: { variant: 'default' as const, label: 'Completed' },
}

export const SessionCard = memo(function SessionCard({
  booking,
  onCancel,
  onReschedule,
  isActioning = false,
}: SessionCardProps) {
  const config = statusConfig[booking.status]
  const startTime = format(parseISO(booking.slot.start_time), 'MMM d, yyyy · h:mm a')
  const endTime = format(parseISO(booking.slot.end_time), 'h:mm a')
  const mentorName = booking.mentor?.name || 'Mentor'

  return (
    <Card className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div className="flex items-start gap-4">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/15 text-primary-light font-semibold">
          {mentorName.charAt(0)}
        </div>
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <h4 className="font-medium text-text">{mentorName}</h4>
            <Badge variant={config.variant}>{config.label}</Badge>
          </div>
          <p className="mt-1 text-sm text-text-muted">
            {startTime} – {endTime}
          </p>
          {booking.member && (
            <p className="mt-0.5 text-xs text-text-dim">Member: {booking.member.name}</p>
          )}
        </div>
      </div>

      {booking.status === 'confirmed' && (onReschedule || onCancel) && (
        <div className="flex shrink-0 gap-2 sm:self-center">
          {onReschedule && (
            <Button size="sm" variant="secondary" onClick={() => onReschedule(booking.id)} disabled={isActioning}>
              Reschedule
            </Button>
          )}
          {onCancel && (
            <Button size="sm" variant="danger" onClick={() => onCancel(booking.id)} disabled={isActioning} loading={isActioning}>
              Cancel
            </Button>
          )}
        </div>
      )}
    </Card>
  )
})
