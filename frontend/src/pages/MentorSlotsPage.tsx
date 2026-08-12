import { useState, useCallback } from 'react'
import { useParams, useNavigate, useSearchParams, useLocation } from 'react-router-dom'
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
import { ConfirmBookingModal } from '../components/ui/ConfirmBookingModal'
import { BookingConfirmationModal } from '../components/ui/BookingConfirmationModal'
import type { Slot } from '../api/types'

export function MentorSlotsPage() {
  const { id: mentorId } = useParams<{ id: string }>()
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const location = useLocation()
  const { showToast } = useToast()
  const { timezone, setTimezone } = useAuth()

  // Get mentor name from navigation state (passed from MentorsPage)
  const mentorName: string = (location.state as { mentorName?: string })?.mentorName || 'Mentor'

  // Detect reschedule mode from URL query param
  const rescheduleBookingId = searchParams.get('reschedule')
  const isRescheduleMode = !!rescheduleBookingId

  const [weekOffset, setWeekOffset] = useState(0)
  const [bookingSlotId, setBookingSlotId] = useState<string | null>(null)

  // Pre-booking confirmation modal state
  const [selectedSlot, setSelectedSlot] = useState<Slot | null>(null)
  // Post-booking success modal state
  const [confirmedBooking, setConfirmedBooking] = useState<{
    mentorName: string
    startTime: string
    endTime: string
  } | null>(null)

  const baseDate = addWeeks(startOfToday(), weekOffset)
  const weekStart = startOfWeek(baseDate, { weekStartsOn: 1 })
  const weekEnd = endOfWeek(baseDate, { weekStartsOn: 1 })

  const startDate = format(weekStart, 'yyyy-MM-dd')
  const endDate = format(weekEnd, 'yyyy-MM-dd')

  const { data: slots, isLoading, isError, refetch } = useSlots(mentorId || '', startDate, endDate)

  const bookMutation = useCreateBooking(mentorId, timezone)
  const rescheduleMutation = useRescheduleBooking(timezone)

  const handleSlotClick = useCallback(
    (slot: Slot) => {
      if (isRescheduleMode && rescheduleBookingId) {
        // RESCHEDULE MODE: proceed directly (no pre-confirm modal needed)
        setBookingSlotId(slot.id)
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
        // NORMAL MODE: Show pre-booking confirmation modal
        setSelectedSlot(slot)
      }
    },
    [rescheduleMutation, showToast, navigate, isRescheduleMode, rescheduleBookingId]
  )

  const handleConfirmBooking = useCallback(() => {
    if (!selectedSlot) return

    setBookingSlotId(selectedSlot.id)
    bookMutation.mutate(selectedSlot.id, {
      onSuccess: () => {
        setBookingSlotId(null)
        setSelectedSlot(null)
        // Show success confirmation modal with calendar options
        setConfirmedBooking({
          mentorName,
          startTime: selectedSlot.start_time,
          endTime: selectedSlot.end_time,
        })
      },
      onError: (error) => {
        const message = (error as { error?: string })?.error || 'Booking failed'
        showToast(message, 'error')
        setBookingSlotId(null)
        setSelectedSlot(null)
      },
    })
  }, [selectedSlot, bookMutation, showToast, mentorName])

  const handleCancelConfirm = useCallback(() => {
    setSelectedSlot(null)
  }, [])

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
          You are rescheduling an existing session. Selecting a new slot will cancel your current booking and create a new one.
        </div>
      )}

      <div className="flex flex-wrap items-center justify-between gap-4">
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
              onSlotClick={handleSlotClick}
              bookingSlotId={bookingSlotId}
              timezone={timezone}
            />
          </PageTransition>
        )}
      </div>

      {/* Pre-booking confirmation modal */}
      <ConfirmBookingModal
        isOpen={!!selectedSlot}
        mentorName={mentorName}
        slotStartTime={selectedSlot?.start_time || ''}
        slotEndTime={selectedSlot?.end_time || ''}
        timezone={timezone}
        isLoading={bookMutation.isPending}
        onConfirm={handleConfirmBooking}
        onCancel={handleCancelConfirm}
      />

      {/* Post-booking success modal with calendar options */}
      <BookingConfirmationModal
        isOpen={!!confirmedBooking}
        mentorName={confirmedBooking?.mentorName || ''}
        slotStartTime={confirmedBooking?.startTime || ''}
        slotEndTime={confirmedBooking?.endTime || ''}
        timezone={timezone}
        onViewSessions={() => navigate('/sessions')}
        onClose={() => setConfirmedBooking(null)}
      />
    </AppShell>
  )
}
