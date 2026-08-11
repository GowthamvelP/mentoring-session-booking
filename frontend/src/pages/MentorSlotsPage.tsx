import { useState, useCallback } from 'react'
import { useParams, useNavigate, useSearchParams } from 'react-router-dom'
import { addWeeks, startOfWeek, endOfWeek, format, isBefore, startOfToday } from 'date-fns'
import { useSlots } from '../hooks/useSlots'
import { useCreateBooking, useRescheduleBooking } from '../hooks/useBooking'
import { useAuth } from '../hooks/useAuth'
import { useToast } from '../context/ToastContext'
import { AppShell } from '../components/layout/AppShell'
import { PageHeader } from '../components/layout/PageHeader'
import { WeekNavigation } from '../components/slots/WeekNavigation'
import { SlotGrid } from '../components/slots/SlotGrid'
import { SlotSkeleton } from '../components/ui/Skeleton'
import { ErrorState } from '../components/ui/ErrorState'
import { Button } from '../components/ui/Button'
import { PageTransition } from '../components/ui/PageTransition'
import { TimezoneSelector } from '../components/ui/TimezoneSelector'
import type { Slot } from '../api/types'

export function MentorSlotsPage() {
  const { id: mentorId } = useParams<{ id: string }>()
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const { showToast } = useToast()
  const { timezone, setTimezone } = useAuth()

  // Detect reschedule mode from URL query param
  const rescheduleBookingId = searchParams.get('reschedule')
  const isRescheduleMode = !!rescheduleBookingId

  const [weekOffset, setWeekOffset] = useState(0)
  const [bookingSlotId, setBookingSlotId] = useState<string | null>(null)

  const baseDate = addWeeks(startOfToday(), weekOffset)
  const weekStart = startOfWeek(baseDate, { weekStartsOn: 1 })
  const weekEnd = endOfWeek(baseDate, { weekStartsOn: 1 })

  const startDate = format(weekStart, 'yyyy-MM-dd')
  const endDate = format(weekEnd, 'yyyy-MM-dd')

  const { data: slots, isLoading, isError, refetch } = useSlots(mentorId || '', startDate, endDate)

  const bookMutation = useCreateBooking(mentorId, timezone)
  const rescheduleMutation = useRescheduleBooking()

  const handleBookSlot = useCallback(
    (slot: Slot) => {
      setBookingSlotId(slot.id)

      if (isRescheduleMode && rescheduleBookingId) {
        // RESCHEDULE MODE: Call reschedule endpoint
        rescheduleMutation.mutate(
          { bookingId: rescheduleBookingId, newSlotId: slot.id },
          {
            onSuccess: () => {
              showToast('Session rescheduled successfully!', 'success')
              setBookingSlotId(null)
              setTimeout(() => navigate('/sessions'), 2000)
            },
            onError: (error) => {
              const message = (error as { error?: string })?.error || 'Reschedule failed'
              showToast(message, 'error')
              setBookingSlotId(null)
            },
          }
        )
      } else {
        // NORMAL MODE: Create new booking
        bookMutation.mutate(slot.id, {
          onSuccess: () => {
            showToast('Session booked successfully!', 'success')
            setBookingSlotId(null)
            setTimeout(() => navigate('/sessions'), 2000)
          },
          onError: (error) => {
            const message = (error as { error?: string })?.error || 'Booking failed'
            showToast(message, 'error')
            setBookingSlotId(null)
          },
        })
      }
    },
    [bookMutation, rescheduleMutation, showToast, navigate, isRescheduleMode, rescheduleBookingId]
  )

  const canGoBack = !isBefore(addWeeks(startOfToday(), weekOffset - 1), startOfToday())

  if (!mentorId) {
    return (
      <AppShell>
        <ErrorState message="Mentor not found" />
      </AppShell>
    )
  }

  return (
    <AppShell>
      <PageHeader
        title={isRescheduleMode ? "Reschedule Session" : "Available Slots"}
        description={isRescheduleMode ? "Pick a new time for your session" : "Choose a time that works for you"}
        action={
          <Button variant="ghost" size="sm" onClick={() => navigate(isRescheduleMode ? '/sessions' : '/mentors')}>
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            {isRescheduleMode ? 'Back to sessions' : 'Back to mentors'}
          </Button>
        }
      />

      {isRescheduleMode && (
        <div className="mb-4 rounded-lg border border-warning/30 bg-warning/5 px-4 py-3 text-sm text-warning">
          ⚠️ You are rescheduling an existing session. Selecting a new slot will cancel your current booking and create a new one.
        </div>
      )}

      <div className="flex items-center justify-between gap-4">
        <WeekNavigation
          currentDate={weekStart}
          onPrevious={() => setWeekOffset((w) => w - 1)}
          onNext={() => setWeekOffset((w) => w + 1)}
          disablePrevious={!canGoBack}
        />
        <div className="flex items-center gap-3">
          <span className="text-xs text-text-dim hidden sm:inline">
            Times shown in your selected timezone
          </span>
          <TimezoneSelector value={timezone} onChange={setTimezone} />
        </div>
      </div>

      <div className="mt-6">
        {isLoading && <SlotSkeleton />}

        {isError && (
          <ErrorState message="Failed to load slots" onRetry={() => refetch()} />
        )}

        {slots && (
          <PageTransition>
            <SlotGrid
              slots={slots}
              onSlotClick={handleBookSlot}
              bookingSlotId={bookingSlotId}
              timezone={timezone}
            />
          </PageTransition>
        )}
      </div>
    </AppShell>
  )
}
