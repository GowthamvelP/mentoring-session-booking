import { useState, useRef, useEffect, useMemo } from 'react'
import { getTimeZones } from '@vvo/tzdb'
import { getBrowserTimezone, getTimezoneAbbreviation } from '../../lib/dates'

interface TimezoneSelectorProps {
  value: string
  onChange: (tz: string) => void
}

export function TimezoneSelector({ value, onChange }: TimezoneSelectorProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [search, setSearch] = useState('')
  const ref = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const browserTz = getBrowserTimezone()

  // Get all timezones from @vvo/tzdb (grouped, with city names)
  const allTimezones = useMemo(() => {
    const tzList = getTimeZones()
    return tzList.map((tz) => ({
      name: tz.name, // IANA name (e.g., "America/New_York")
      label: tz.currentTimeFormat, // e.g., "+05:30 India Standard Time - Kolkata, Mumbai"
      abbreviation: tz.abbreviation, // e.g., "IST"
      offset: tz.currentTimeOffsetInMinutes,
      mainCities: tz.mainCities.slice(0, 2).join(', '),
      group: tz.group.join(', '),
    }))
  }, [])

  // Filter based on search
  const filteredTimezones = useMemo(() => {
    if (!search.trim()) return allTimezones.slice(0, 30) // Show top 30 by default
    const term = search.toLowerCase()
    return allTimezones.filter((tz) =>
      tz.name.toLowerCase().includes(term) ||
      tz.label.toLowerCase().includes(term) ||
      tz.abbreviation.toLowerCase().includes(term) ||
      tz.mainCities.toLowerCase().includes(term)
    ).slice(0, 20)
  }, [search, allTimezones])

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        setIsOpen(false)
        setSearch('')
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus()
    }
  }, [isOpen])

  // Find current timezone display info
  const currentTz = allTimezones.find((tz) => tz.name === value)
  const displayName = currentTz
    ? `${currentTz.abbreviation} — ${currentTz.mainCities || value.split('/').pop()?.replace(/_/g, ' ')}`
    : getTimezoneAbbreviation(value)

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-1.5 rounded-md border border-surface-border bg-surface-card px-3 py-1.5 text-xs font-medium text-text-muted hover:border-primary/50 hover:text-text transition-colors cursor-pointer"
        aria-label="Change timezone"
      >
        <svg className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span className="max-w-[180px] truncate">{displayName}</span>
        <svg className={`h-3 w-3 flex-shrink-0 transition-transform ${isOpen ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {isOpen && (
        <div className="absolute right-0 top-full z-50 mt-1 w-80 rounded-lg border border-surface-border bg-surface-card shadow-xl">
          {/* Search input */}
          <div className="border-b border-surface-border p-2">
            <input
              ref={inputRef}
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search timezone or city..."
              className="w-full rounded-md border border-surface-border bg-surface px-3 py-1.5 text-xs text-text placeholder:text-text-dim focus:border-primary focus:outline-none"
            />
          </div>

          {/* Timezone list */}
          <div className="max-h-64 overflow-y-auto">
            {filteredTimezones.map((tz) => (
              <button
                key={tz.name}
                onClick={() => { onChange(tz.name); setIsOpen(false); setSearch('') }}
                className={`w-full px-3 py-2 text-left text-xs transition-colors cursor-pointer ${
                  tz.name === value
                    ? 'bg-primary/10 text-primary-light'
                    : 'text-text-muted hover:bg-surface-hover hover:text-text'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className="font-medium">{tz.abbreviation}</span>
                  <span className="text-text-dim text-[10px]">
                    {tz.offset >= 0 ? '+' : ''}{Math.floor(tz.offset / 60)}:{String(Math.abs(tz.offset % 60)).padStart(2, '0')}
                  </span>
                </div>
                <div className="mt-0.5 text-text-dim truncate">
                  {tz.mainCities || tz.name.split('/').pop()?.replace(/_/g, ' ')}
                </div>
                {tz.name === browserTz && (
                  <span className="text-accent text-[10px] font-medium">Your local timezone</span>
                )}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
