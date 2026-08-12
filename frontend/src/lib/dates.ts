/**
 * Get the calendar date (yyyy-MM-dd) for a UTC ISO string in a specific timezone.
 * Uses native Intl API — always correct regardless of browser timezone.
 */
export function getDateInTimezone(utcIsoString: string, timezone: string): string {
  const date = new Date(utcIsoString)
  return new Intl.DateTimeFormat('en-CA', { timeZone: timezone }).format(date)
}

/**
 * Get the display date header (e.g., "THURSDAY, AUG 13") for a UTC timestamp.
 */
export function formatDateHeader(utcIsoString: string, timezone: string): string {
  const date = new Date(utcIsoString)
  return new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    weekday: 'long',
    month: 'short',
    day: 'numeric',
  }).format(date).toUpperCase()
}

/**
 * Format a UTC ISO timestamp for time display (e.g., "11:00 AM").
 */
export function formatSlotTime(utcIsoString: string, timezone: string): string {
  const date = new Date(utcIsoString)
  return new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  }).format(date)
}

/**
 * Format a UTC ISO timestamp as full date + time (e.g., "Aug 13, 2026, 11:00 AM").
 */
export function formatSlotDateTime(utcIsoString: string, timezone: string): string {
  const date = new Date(utcIsoString)
  return new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  }).format(date)
}

/**
 * Format a date range (e.g., "11:00 AM – 12:00 PM").
 */
export function formatSlotRange(startUtc: string, endUtc: string, timezone: string): string {
  return `${formatSlotTime(startUtc, timezone)} – ${formatSlotTime(endUtc, timezone)}`
}

/**
 * Get the timezone abbreviation (e.g., "EST", "CDT", "IST").
 */
export function getTimezoneAbbreviation(timezone: string): string {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      timeZoneName: 'short',
    }).formatToParts(new Date())
    return parts.find(p => p.type === 'timeZoneName')?.value || timezone
  } catch {
    return timezone
  }
}

/**
 * Get the effective timezone: user preference > browser detected > org default.
 */
export function getEffectiveTimezone(userTimezone?: string | null, orgTimezone?: string): string {
  if (userTimezone) return userTimezone
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone
  } catch {
    return orgTimezone || 'UTC'
  }
}

/**
 * Get browser's detected timezone.
 */
export function getBrowserTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone
  } catch {
    return 'UTC'
  }
}

/**
 * Format a UTC ISO timestamp as a date string (e.g., "Thursday, Aug 13, 2026").
 */
export function formatSlotDate(utcIsoString: string, timezone: string): string {
  const date = new Date(utcIsoString)
  return new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    weekday: 'long',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(date)
}
