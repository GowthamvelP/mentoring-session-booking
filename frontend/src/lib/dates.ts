import { format, parseISO } from 'date-fns'

export function formatSlotTime(isoString: string): string {
  return format(parseISO(isoString), 'h:mm a')
}

export function formatSlotDate(isoString: string): string {
  return format(parseISO(isoString), 'EEEE, MMM d')
}

export function formatSessionDate(isoString: string): string {
  return format(parseISO(isoString), 'MMM d, yyyy · h:mm a')
}
