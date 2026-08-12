import { Button } from './Button'
import { formatSlotDateTime, formatSlotTime, getTimezoneAbbreviation } from '../../lib/dates'

interface BookingConfirmationModalProps {
  isOpen: boolean
  mentorName: string
  slotStartTime: string
  slotEndTime: string
  timezone: string
  onViewSessions: () => void
  onClose: () => void
}

function generateGoogleCalendarUrl(title: string, start: string, end: string, timezone: string): string {
  // Google Calendar expects: YYYYMMDDTHHmmSSZ format
  const startDate = new Date(start)
  const endDate = new Date(end)
  const formatGCal = (d: Date) => d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')
  return `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${encodeURIComponent(title)}&dates=${formatGCal(startDate)}/${formatGCal(endDate)}&ctz=${timezone}`
}

function generateICSContent(title: string, start: string, end: string): string {
  const startDate = new Date(start)
  const endDate = new Date(end)
  const formatICS = (d: Date) => d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')
  return `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART:${formatICS(startDate)}
DTEND:${formatICS(endDate)}
SUMMARY:${title}
END:VEVENT
END:VCALENDAR`
}

export function BookingConfirmationModal({
  isOpen,
  mentorName,
  slotStartTime,
  slotEndTime,
  timezone,
  onViewSessions,
  onClose,
}: BookingConfirmationModalProps) {
  if (!isOpen) return null

  const title = `Mentoring Session with ${mentorName}`
  const displayDate = formatSlotDateTime(slotStartTime, timezone)
  const displayTime = `${formatSlotTime(slotStartTime, timezone)} \u2013 ${formatSlotTime(slotEndTime, timezone)}`
  const tzAbbr = getTimezoneAbbreviation(timezone)

  const googleUrl = generateGoogleCalendarUrl(title, slotStartTime, slotEndTime, timezone)

  const handleDownloadICS = () => {
    const ics = generateICSContent(title, slotStartTime, slotEndTime)
    const blob = new Blob([ics], { type: 'text/calendar' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'mentoring-session.ics'
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={onClose}>
      <div className="w-full max-w-md rounded-xl border border-surface-border bg-surface-card p-6 shadow-2xl animate-page-enter" onClick={(e) => e.stopPropagation()}>
        {/* Success icon */}
        <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-success/20">
          <svg className="h-7 w-7 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
          </svg>
        </div>

        <h2 className="text-center text-lg font-bold text-text">Session Booked!</h2>
        <p className="mt-1 text-center text-sm text-text-muted">Your mentoring session has been confirmed</p>

        {/* Session details */}
        <div className="mt-5 rounded-lg border border-surface-border bg-surface p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-primary/15 text-primary-light font-semibold">
              {mentorName.charAt(0)}
            </div>
            <div>
              <p className="font-medium text-text">{mentorName}</p>
              <p className="text-sm text-text-muted">{displayDate}</p>
              <p className="text-xs text-text-dim">{displayTime} ({tzAbbr})</p>
            </div>
          </div>
        </div>

        {/* Add to Calendar */}
        <div className="mt-4">
          <p className="mb-2 text-xs font-medium text-text-dim uppercase">Add to Calendar</p>
          <div className="flex gap-2">
            <a
              href={googleUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex-1 rounded-md border border-surface-border bg-surface px-3 py-2 text-center text-xs font-medium text-text-muted hover:border-primary/50 hover:text-text transition-colors"
            >
              Google
            </a>
            <button
              onClick={handleDownloadICS}
              className="flex-1 rounded-md border border-surface-border bg-surface px-3 py-2 text-xs font-medium text-text-muted hover:border-primary/50 hover:text-text transition-colors cursor-pointer"
            >
              Apple / Outlook (.ics)
            </button>
          </div>
        </div>

        {/* Actions */}
        <div className="mt-6 flex gap-3">
          <Button variant="secondary" className="flex-1" onClick={onClose}>
            Book Another
          </Button>
          <Button className="flex-1" onClick={onViewSessions}>
            View My Sessions
          </Button>
        </div>
      </div>
    </div>
  )
}
