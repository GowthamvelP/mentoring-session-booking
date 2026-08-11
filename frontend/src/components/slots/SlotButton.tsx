import { memo } from 'react'
import type { Slot } from '../../api/types'
import { format } from 'date-fns'

interface SlotButtonProps {
  slot: Slot
  onClick?: () => void
  disabled?: boolean
  loading?: boolean
}

export const SlotButton = memo(function SlotButton({ slot, onClick, disabled = false, loading = false }: SlotButtonProps) {
  const startTime = format(new Date(slot.start_time), 'h:mm a')
  const endTime = format(new Date(slot.end_time), 'h:mm a')
  const isBooked = slot.status === 'booked'

  return (
    <button
      onClick={onClick}
      disabled={disabled || loading || isBooked}
      className={`
        group relative rounded-md border px-3 py-2 text-sm font-medium transition-all duration-200
        ${isBooked
          ? 'border-surface-border/50 bg-surface-hover/40 text-text-dim cursor-not-allowed opacity-60'
          : loading
            ? 'border-primary bg-primary/10 text-primary-light cursor-wait'
            : 'border-surface-border bg-surface-card text-text hover:border-primary hover:bg-primary/10 hover:text-primary-light hover:shadow-sm active:scale-[0.98]'
        }
        disabled:cursor-not-allowed
      `}
      aria-label={`${isBooked ? 'Slot unavailable' : 'Book slot'} ${startTime} to ${endTime}`}
    >
      {loading ? (
        <span className="flex items-center gap-2">
          <svg className="h-3 w-3 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          Booking...
        </span>
      ) : (
        <span>{startTime} – {endTime}</span>
      )}
    </button>
  )
})
