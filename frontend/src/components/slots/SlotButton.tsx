import type { Slot } from '../../api/types'

interface SlotButtonProps {
  slot: Slot
  onClick?: () => void
  disabled?: boolean
  loading?: boolean
}

export function SlotButton({ slot, onClick, disabled = false, loading = false }: SlotButtonProps) {
  const startTime = new Date(slot.start_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  const endTime = new Date(slot.end_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })

  return (
    <button
      onClick={onClick}
      disabled={disabled || loading}
      className="rounded-lg border border-surface-border bg-surface-card px-4 py-2 text-sm text-text transition-colors hover:bg-primary hover:text-white hover:border-primary disabled:opacity-50 disabled:cursor-not-allowed"
      aria-label={`Book slot from ${startTime} to ${endTime}`}
    >
      {loading ? 'Booking...' : `${startTime} - ${endTime}`}
    </button>
  )
}
