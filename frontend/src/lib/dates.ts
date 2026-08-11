import { format, parseISO } from 'date-fns'
import { toZonedTime } from 'date-fns-tz'

export function formatSlotTime(isoString: string, timezone?: string): string {
  const date = parseISO(isoString)
  const zoned = timezone ? toZonedTime(date, timezone) : date
  return format(zoned, 'h:mm a')
}

export function formatSlotDate(isoString: string, timezone?: string): string {
  const date = parseISO(isoString)
  const zoned = timezone ? toZonedTime(date, timezone) : date
  return format(zoned, 'EEE, MMM d')
}

export function formatFullDateTime(isoString: string, timezone?: string): string {
  const date = parseISO(isoString)
  const zoned = timezone ? toZonedTime(date, timezone) : date
  return format(zoned, 'MMM d, yyyy h:mm a')
}
