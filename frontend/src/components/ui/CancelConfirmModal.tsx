import { useState } from "react"
import { Button } from './Button'
import { formatSlotDateTime, formatSlotTime, getTimezoneAbbreviation } from '../../lib/dates'

interface CancelConfirmModalProps {
  isOpen: boolean
  mentorName: string
  slotStartTime: string
  slotEndTime: string
  timezone: string
  isLoading: boolean
  onConfirm: (reason?: string) => void
  onCancel: () => void
}

export function CancelConfirmModal({
  isOpen,
  mentorName,
  slotStartTime,
  slotEndTime,
  timezone,
  isLoading,
  onConfirm,
  onCancel,
}: CancelConfirmModalProps) {
  const [reason, setReason] = useState("")

  if (!isOpen) return null

  const date = formatSlotDateTime(slotStartTime, timezone)
  const timeRange = `${formatSlotTime(slotStartTime, timezone)} – ${formatSlotTime(slotEndTime, timezone)}`
  const tzAbbr = getTimezoneAbbreviation(timezone)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={onCancel}>
      <div className="w-full max-w-sm rounded-xl border border-surface-border bg-surface-card p-6 shadow-2xl animate-page-enter" onClick={(e) => e.stopPropagation()}>
        {/* Warning icon */}
        <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-danger/15">
          <svg className="h-6 w-6 text-danger" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        </div>

        <h3 className="text-center text-lg font-bold text-text">Cancel Session?</h3>
        <p className="mt-1 text-center text-sm text-text-muted">
          This action cannot be undone. The slot will become available for others.
        </p>

        <div className="mt-4 rounded-lg border border-surface-border bg-surface p-3">
          <p className="text-sm font-medium text-text">{mentorName}</p>
          <p className="text-sm text-text-muted">{date}</p>
          <p className="text-xs text-text-dim">{timeRange} ({tzAbbr})</p>
        </div>

        <div className="mt-4">
          <label className="text-xs text-text-dim mb-1 block">Reason (optional)</label>
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Why are you cancelling?"
            className="w-full rounded-lg border border-surface-border bg-surface p-2 text-sm text-text placeholder-text-dim focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary resize-none"
            rows={2}
          />
        </div>

        <div className="mt-4 flex gap-3">
          <Button variant="secondary" className="flex-1" onClick={onCancel} disabled={isLoading}>
            Keep Session
          </Button>
          <Button variant="danger" className="flex-1" onClick={() => onConfirm(reason || undefined)} loading={isLoading}>
            Yes, Cancel
          </Button>
        </div>
      </div>
    </div>
  )
}
