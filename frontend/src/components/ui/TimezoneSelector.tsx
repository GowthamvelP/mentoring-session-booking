import { useState, useRef, useEffect } from 'react'
import { getBrowserTimezone, getTimezoneAbbreviation } from '../../lib/dates'

// Common timezones for the dropdown
const COMMON_TIMEZONES = [
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Toronto',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Asia/Dubai',
  'Asia/Kolkata',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Australia/Sydney',
  'Pacific/Auckland',
]

interface TimezoneSelectorProps {
  value: string
  onChange: (tz: string) => void
}

export function TimezoneSelector({ value, onChange }: TimezoneSelectorProps) {
  const [isOpen, setIsOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const browserTz = getBrowserTimezone()

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Ensure browser timezone is in the list
  const timezones = COMMON_TIMEZONES.includes(browserTz)
    ? COMMON_TIMEZONES
    : [browserTz, ...COMMON_TIMEZONES]

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-1.5 rounded-md border border-surface-border bg-surface-card px-3 py-1.5 text-xs font-medium text-text-muted hover:border-primary/50 hover:text-text transition-colors cursor-pointer"
        aria-label="Change timezone"
      >
        <svg className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        {getTimezoneAbbreviation(value)}
        <svg className={`h-3 w-3 transition-transform ${isOpen ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {isOpen && (
        <div className="absolute right-0 top-full z-50 mt-1 max-h-64 w-56 overflow-y-auto rounded-lg border border-surface-border bg-surface-card shadow-xl">
          {timezones.map((tz) => (
            <button
              key={tz}
              onClick={() => { onChange(tz); setIsOpen(false) }}
              className={`w-full px-3 py-2 text-left text-xs transition-colors cursor-pointer ${
                tz === value
                  ? 'bg-primary/10 text-primary-light font-medium'
                  : 'text-text-muted hover:bg-surface-hover hover:text-text'
              }`}
            >
              <span className="font-medium">{getTimezoneAbbreviation(tz)}</span>
              <span className="ml-2 text-text-dim">{tz.replace(/_/g, ' ')}</span>
              {tz === browserTz && <span className="ml-1 text-accent text-[10px]">(local)</span>}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
