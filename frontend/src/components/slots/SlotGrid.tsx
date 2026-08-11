import { useMemo } from 'react'
import { parseISO } from 'date-fns'
import { toZonedTime, format as formatTz } from 'date-fns-tz'
import type { Slot } from '../../api/types'
import { SlotButton } from './SlotButton'

interface SlotGridProps {
  slots: Slot[]
  onSlotClick?: (slot: Slot) => void
  bookingSlotId?: string | null
  timezone: string
}

export function SlotGrid({ slots, onSlotClick, bookingSlotId, timezone }: SlotGridProps) {
  const groupedSlots = useMemo(() => {
    const groups: Record<string, Slot[]> = {}
    const available = slots.filter((s) => s.status === 'available')

    for (const slot of available) {
      // Group by date in the user's selected timezone
      const zonedDate = toZonedTime(parseISO(slot.start_time), timezone)
      const date = formatTz(zonedDate, 'yyyy-MM-dd', { timeZone: timezone })
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
  }, [slots, timezone])

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
            {formatTz(toZonedTime(parseISO(date), timezone), 'EEEE, MMM d', { timeZone: timezone })}
          </h3>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
            {daySlots.map((slot) => (
              <SlotButton
                key={slot.id}
                slot={slot}
                onClick={() => onSlotClick?.(slot)}
                loading={bookingSlotId === slot.id}
                disabled={bookingSlotId !== null && bookingSlotId !== undefined && bookingSlotId !== slot.id}
                timezone={timezone}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}
