import { parseISO } from 'date-fns'
import { toZonedTime, format as formatTz } from 'date-fns-tz'

/**
 * Get the effective timezone for display:
 * 1. User's explicit timezone preference (if set)
 * 2. Browser's detected timezone (Intl API)
 * 3. Organization's default timezone (fallback)
 */
export function getEffectiveTimezone(userTimezone?: string | null, orgTimezone?: string): string {
  if (userTimezone) return userTimezone

  // Detect browser's local timezone
  try {
    const detected = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (detected) return detected
  } catch {
    // Fallback if Intl API not available
  }

  return orgTimezone || 'UTC'
}

/**
 * Format a UTC ISO timestamp for display in the user's timezone.
 * Handles DST transitions automatically via date-fns-tz.
 */
export function formatSlotTime(utcIsoString: string, timezone: string): string {
  const date = parseISO(utcIsoString)
  const zonedDate = toZonedTime(date, timezone)
  return formatTz(zonedDate, 'h:mm a', { timeZone: timezone })
}

/**
 * Format a UTC ISO timestamp as a full date for display.
 */
export function formatSlotDate(utcIsoString: string, timezone: string): string {
  const date = parseISO(utcIsoString)
  const zonedDate = toZonedTime(date, timezone)
  return formatTz(zonedDate, 'EEE, MMM d', { timeZone: timezone })
}

/**
 * Format a UTC ISO timestamp as full date + time.
 */
export function formatSlotDateTime(utcIsoString: string, timezone: string): string {
  const date = parseISO(utcIsoString)
  const zonedDate = toZonedTime(date, timezone)
  return formatTz(zonedDate, 'MMM d, yyyy · h:mm a', { timeZone: timezone })
}

/**
 * Format a date range (start - end) for a slot.
 */
export function formatSlotRange(startUtc: string, endUtc: string, timezone: string): string {
  const start = formatSlotTime(startUtc, timezone)
  const end_ = formatSlotTime(endUtc, timezone)
  return `${start} – ${end_}`
}

/**
 * Get the timezone abbreviation (e.g., "EST", "EDT", "IST")
 */
export function getTimezoneAbbreviation(timezone: string): string {
  try {
    const date = new Date()
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      timeZoneName: 'short',
    })
    const parts = formatter.formatToParts(date)
    const tzPart = parts.find(p => p.type === 'timeZoneName')
    return tzPart?.value || timezone
  } catch {
    return timezone
  }
}

/**
 * Get browser's detected timezone
 */
export function getBrowserTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone
  } catch {
    return 'UTC'
  }
}
