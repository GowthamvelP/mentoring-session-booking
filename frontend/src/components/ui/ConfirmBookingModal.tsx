import { Button } from './Button'
import { formatSlotTime, formatSlotDate, getTimezoneAbbreviation } from '../../lib/dates'

interface ConfirmBookingModalProps {
  isOpen: boolean
  mentorName: string
  slotStartTime: string
  slotEndTime: string
  timezone: string
  isLoading: boolean
  onConfirm: () => void
  onCancel: () => void
}

export function ConfirmBookingModal({
  isOpen,
  mentorName,
  slotStartTime,
  slotEndTime,
  timezone,
  isLoading,
  onConfirm,
  onCancel,
}: ConfirmBookingModalProps) {
  if (!isOpen) return null

  const date = formatSlotDate(slotStartTime, timezone)
  const timeRange = `${formatSlotTime(slotStartTime, timezone)} \u2013 ${formatSlotTime(slotEndTime, timezone)}`
  const tzAbbr = getTimezoneAbbreviation(timezone)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={onCancel}>
      <div className="w-full max-w-sm rounded-xl border border-surface-border bg-surface-card p-6 shadow-2xl animate-page-enter" onClick={(e) => e.stopPropagation()}>
        <h3 className="text-lg font-bold text-text">Confirm Booking</h3>
        <p className="mt-1 text-sm text-text-muted">Book a session with {mentorName}?</p>

        <div className="mt-4 rounded-lg border border-surface-border bg-surface p-3">
          <p className="text-sm font-medium text-text">{date}</p>
          <p className="text-sm text-text-muted">{timeRange} <span className="text-text-dim">({tzAbbr})</span></p>
        </div>

        <div className="mt-5 flex gap-3">
          <Button variant="secondary" className="flex-1" onClick={onCancel} disabled={isLoading}>
            Cancel
          </Button>
          <Button className="flex-1" onClick={onConfirm} loading={isLoading}>
            Confirm
          </Button>
        </div>
      </div>
    </div>
  )
}
