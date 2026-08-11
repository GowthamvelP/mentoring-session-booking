import { useMemo } from 'react'
import { format, parseISO } from 'date-fns'
import type { Slot } from '../../api/types'
import { SlotButton } from './SlotButton'

interface SlotGridProps {
  slots: Slot[]
  onSlotClick?: (slot: Slot) => void
  bookingSlotId?: string | null
}

export function SlotGrid({ slots, onSlotClick, bookingSlotId }: SlotGridProps) {
  const groupedSlots = useMemo(() => {
    const groups: Record<string, Slot[]> = {}
    const available = slots.filter((s) => s.status === 'available')

    for (const slot of available) {
      const date = format(parseISO(slot.start_time), 'yyyy-MM-dd')
      if (!groups[date]) groups[date] = []
      groups[date].push(slot)
    }

    // Sort each group by start_time
    for (const date of Object.keys(groups)) {
      groups[date].sort(
        (a, b) => new Date(a.start_time).getTime() - new Date(b.start_time).getTime()
      )
    }

    return Object.entries(groups).sort(([a], [b]) => a.localeCompare(b))
  }, [slots])

  if (groupedSlots.length === 0) {
    return (
      <div className="py-12 text-center">
        <p className="text-text-muted">No available slots this week.</p>
        <p className="mt-1 text-sm text-text-dim">Try navigating to a different week.</p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {groupedSlots.map(([date, daySlots]) => (
        <div key={date}>
          <h3 className="mb-3 text-sm font-semibold text-text-muted uppercase tracking-wide">
            {format(parseISO(date), 'EEEE, MMM d')}
          </h3>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
            {daySlots.map((slot) => (
              <SlotButton
                key={slot.id}
                slot={slot}
                onClick={() => onSlotClick?.(slot)}
                loading={bookingSlotId === slot.id}
                disabled={bookingSlotId !== null && bookingSlotId !== undefined && bookingSlotId !== slot.id}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}
