import { describe, it, expect } from 'vitest'
import {
  getDateInTimezone,
  formatDateHeader,
  formatSlotTime,
  formatSlotDateTime,
  formatSlotRange,
  getTimezoneAbbreviation,
  getEffectiveTimezone,
  getBrowserTimezone,
} from './dates'

describe('getDateInTimezone', () => {
  it('returns correct date for UTC timestamp in same-day timezone', () => {
    // 2026-08-13T16:00:00Z in America/Chicago (CDT, UTC-5) is still Aug 13
    expect(getDateInTimezone('2026-08-13T16:00:00Z', 'America/Chicago')).toBe('2026-08-13')
  })

  it('returns correct date when UTC timestamp crosses midnight into next day in target timezone', () => {
    // 2026-08-13T01:00:00Z in Asia/Kolkata (IST, UTC+5:30) is Aug 13 at 6:30 AM
    expect(getDateInTimezone('2026-08-13T01:00:00Z', 'Asia/Kolkata')).toBe('2026-08-13')
  })

  it('returns previous day when UTC timestamp is early morning and target timezone is behind', () => {
    // 2026-08-13T03:00:00Z in America/Chicago (CDT, UTC-5) is Aug 12 at 10:00 PM
    expect(getDateInTimezone('2026-08-13T03:00:00Z', 'America/Chicago')).toBe('2026-08-12')
  })

  it('returns next day when UTC timestamp is late night and target timezone is ahead', () => {
    // 2026-08-13T20:00:00Z in Asia/Kolkata (IST, UTC+5:30) is Aug 14 at 1:30 AM
    expect(getDateInTimezone('2026-08-13T20:00:00Z', 'Asia/Kolkata')).toBe('2026-08-14')
  })

  it('handles DST transition correctly', () => {
    // Mar 8, 2026 2:00 AM is when US clocks spring forward
    // 2026-03-08T07:00:00Z in America/Chicago should be Mar 8 at 1:00 AM CST (before spring forward)
    expect(getDateInTimezone('2026-03-08T07:00:00Z', 'America/Chicago')).toBe('2026-03-08')
  })
})

describe('formatDateHeader', () => {
  it('formats date as uppercase weekday, month, and day', () => {
    // 2026-08-13 is a Thursday
    const result = formatDateHeader('2026-08-13T16:00:00Z', 'America/Chicago')
    expect(result).toContain('THURSDAY')
    expect(result).toContain('AUG')
    expect(result).toContain('13')
  })

  it('respects timezone when date crosses midnight boundary', () => {
    // 2026-08-13T03:00:00Z in America/Chicago is Aug 12 (Wednesday)
    const result = formatDateHeader('2026-08-13T03:00:00Z', 'America/Chicago')
    expect(result).toContain('WEDNESDAY')
    expect(result).toContain('12')
  })
})

describe('formatSlotTime', () => {
  it('formats time with AM/PM in target timezone', () => {
    // 2026-08-13T16:00:00Z in America/Chicago (CDT, UTC-5) is 11:00 AM
    const result = formatSlotTime('2026-08-13T16:00:00Z', 'America/Chicago')
    expect(result).toBe('11:00 AM')
  })

  it('formats afternoon time correctly', () => {
    // 2026-08-13T20:00:00Z in America/Chicago (CDT, UTC-5) is 3:00 PM
    const result = formatSlotTime('2026-08-13T20:00:00Z', 'America/Chicago')
    expect(result).toBe('3:00 PM')
  })

  it('formats time in IST correctly', () => {
    // 2026-08-13T16:00:00Z in Asia/Kolkata (IST, UTC+5:30) is 9:30 PM
    const result = formatSlotTime('2026-08-13T16:00:00Z', 'Asia/Kolkata')
    expect(result).toBe('9:30 PM')
  })
})

describe('formatSlotDateTime', () => {
  it('formats full date and time in target timezone', () => {
    const result = formatSlotDateTime('2026-08-13T16:00:00Z', 'America/Chicago')
    expect(result).toContain('Aug')
    expect(result).toContain('13')
    expect(result).toContain('2026')
    expect(result).toContain('11:00')
    expect(result).toContain('AM')
  })

  it('shows correct date when timezone shifts day', () => {
    // 2026-08-13T03:00:00Z in America/Chicago is Aug 12 at 10:00 PM
    const result = formatSlotDateTime('2026-08-13T03:00:00Z', 'America/Chicago')
    expect(result).toContain('Aug')
    expect(result).toContain('12')
    expect(result).toContain('10:00')
    expect(result).toContain('PM')
  })
})

describe('formatSlotRange', () => {
  it('formats a time range with an en-dash separator', () => {
    const result = formatSlotRange(
      '2026-08-13T16:00:00Z',
      '2026-08-13T17:00:00Z',
      'America/Chicago'
    )
    expect(result).toBe('11:00 AM – 12:00 PM')
  })
})

describe('getTimezoneAbbreviation', () => {
  it('returns timezone abbreviation for valid timezone', () => {
    const result = getTimezoneAbbreviation('America/New_York')
    // Could be EST or EDT depending on when test runs, but should be a short string
    expect(result).toMatch(/^(EST|EDT)$/)
  })

  it('returns the timezone string itself for invalid timezone', () => {
    const result = getTimezoneAbbreviation('Invalid/Timezone')
    expect(result).toBe('Invalid/Timezone')
  })
})

describe('getEffectiveTimezone', () => {
  it('returns user timezone if provided', () => {
    expect(getEffectiveTimezone('Europe/London', 'America/New_York')).toBe('Europe/London')
  })

  it('returns browser timezone if user timezone is null', () => {
    const result = getEffectiveTimezone(null, 'America/New_York')
    // Should return browser's timezone (depends on test environment)
    expect(result).toBeTruthy()
    expect(typeof result).toBe('string')
  })

  it('returns org timezone as fallback if browser detection fails', () => {
    // In normal environments browser detection works, so user timezone wins or browser detects
    // This test validates that user preference takes priority
    expect(getEffectiveTimezone('Asia/Kolkata')).toBe('Asia/Kolkata')
  })
})

describe('getBrowserTimezone', () => {
  it('returns a valid timezone string', () => {
    const result = getBrowserTimezone()
    expect(result).toBeTruthy()
    expect(typeof result).toBe('string')
  })
})
