import { useState, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { addWeeks, startOfWeek, endOfWeek, format, isBefore, startOfToday } from 'date-fns'
import { useSlots } from '../hooks/useSlots'
import { useCreateBooking } from '../hooks/useBooking'
import { useToast } from '../context/ToastContext'
import { AppShell } from '../components/layout/AppShell'
import { PageHeader } from '../components/layout/PageHeader'
import { WeekNavigation } from '../components/slots/WeekNavigation'
import { SlotGrid } from '../components/slots/SlotGrid'
import { SlotSkeleton } from '../components/ui/Skeleton'
import { ErrorState } from '../components/ui/ErrorState'
import { Button } from '../components/ui/Button'
import { PageTransition } from '../components/ui/PageTransition'
import type { Slot } from '../api/types'

export function MentorSlotsPage() {
  const { id: mentorId } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { showToast } = useToast()

  const [weekOffset, setWeekOffset] = useState(0)
  const [bookingSlotId, setBookingSlotId] = useState<string | null>(null)

  const baseDate = addWeeks(startOfToday(), weekOffset)
  const weekStart = startOfWeek(baseDate, { weekStartsOn: 1 })
  const weekEnd = endOfWeek(baseDate, { weekStartsOn: 1 })

  const startDate = format(weekStart, 'yyyy-MM-dd')
  const endDate = format(weekEnd, 'yyyy-MM-dd')

  const { data: slots, isLoading, isError, refetch } = useSlots(mentorId || '', startDate, endDate)

  const bookMutation = useCreateBooking(mentorId)

  const handleBookSlot = useCallback(
    (slot: Slot) => {
      setBookingSlotId(slot.id)
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
    },
    [bookMutation, showToast, navigate]
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
        title="Available Slots"
        description="Choose a time that works for you"
        action={
          <Button variant="ghost" size="sm" onClick={() => navigate('/mentors')}>
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            Back to mentors
          </Button>
        }
      />

      <WeekNavigation
        currentDate={weekStart}
        onPrevious={() => setWeekOffset((w) => w - 1)}
        onNext={() => setWeekOffset((w) => w + 1)}
        disablePrevious={!canGoBack}
      />

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
            />
          </PageTransition>
        )}
      </div>
    </AppShell>
  )
}
