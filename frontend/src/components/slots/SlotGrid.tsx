import type { Slot } from '../../api/types'
import { SlotButton } from './SlotButton'

interface SlotGridProps {
  slots: Slot[]
  onSlotClick?: (slot: Slot) => void
  bookingSlotId?: string | null
}

export function SlotGrid({ slots, onSlotClick, bookingSlotId }: SlotGridProps) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
      {slots.map((slot) => (
        <SlotButton
          key={slot.id}
          slot={slot}
          onClick={() => onSlotClick?.(slot)}
          loading={bookingSlotId === slot.id}
          disabled={bookingSlotId !== null && bookingSlotId !== undefined}
        />
      ))}
    </div>
  )
}
