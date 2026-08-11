import { useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { isFuture, parseISO } from 'date-fns'
import { useMySessions } from '../hooks/useSessions'
import { useCancelBooking } from '../hooks/useBooking'
import { useToast } from '../context/ToastContext'
import { AppShell } from '../components/layout/AppShell'
import { PageHeader } from '../components/layout/PageHeader'
import { SessionList } from '../components/sessions/SessionList'
import { CardSkeleton } from '../components/ui/Skeleton'
import { EmptyState } from '../components/ui/EmptyState'
import { ErrorState } from '../components/ui/ErrorState'
import { PageTransition } from '../components/ui/PageTransition'

export function MySessionsPage() {
  const navigate = useNavigate()
  const { data, isLoading, isError, refetch } = useMySessions()
  const cancelMutation = useCancelBooking()
  const { showToast } = useToast()

  const { upcoming, past } = useMemo(() => {
    if (!data?.data) return { upcoming: [], past: [] }

    const upcoming = data.data.filter(
      (b) => b.status === 'confirmed' && isFuture(parseISO(b.slot.start_time))
    )
    const past = data.data.filter(
      (b) => b.status !== 'confirmed' || !isFuture(parseISO(b.slot.start_time))
    )
    return { upcoming, past }
  }, [data])

  const handleCancel = (bookingId: string) => {
    cancelMutation.mutate(bookingId, {
      onSuccess: () => showToast('Session cancelled', 'success'),
      onError: () => showToast('Failed to cancel session', 'error'),
    })
  }

  const handleReschedule = (bookingId: string) => {
    const booking = data?.data.find((b) => b.id === bookingId)
    if (booking?.mentor?.id) {
      navigate(`/mentors/${booking.mentor.id}/slots`)
    }
  }

  return (
    <AppShell>
      <PageHeader
        title="My Sessions"
        description="Manage your upcoming and past mentoring sessions"
      />

      {isLoading && (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <CardSkeleton key={i} />
          ))}
        </div>
      )}

      {isError && (
        <ErrorState message="Failed to load sessions" onRetry={() => refetch()} />
      )}

      {data && data.data.length === 0 && (
        <EmptyState
          title="No sessions yet"
          description="Book your first mentoring session to get started."
          icon={
            <svg className="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
          }
        />
      )}

      {data && data.data.length > 0 && (
        <PageTransition>
          <div className="space-y-8">
            {upcoming.length > 0 && (
              <section>
                <h2 className="mb-4 text-lg font-semibold text-text">
                  Upcoming
                  <span className="ml-2 text-sm font-normal text-text-dim">({upcoming.length})</span>
                </h2>
                <SessionList
                  bookings={upcoming}
                  onCancel={handleCancel}
                  onReschedule={handleReschedule}
                  actioningId={cancelMutation.isPending ? cancelMutation.variables : null}
                />
              </section>
            )}

            {past.length > 0 && (
              <section>
                <h2 className="mb-4 text-lg font-semibold text-text">
                  Past & Cancelled
                  <span className="ml-2 text-sm font-normal text-text-dim">({past.length})</span>
                </h2>
                <SessionList bookings={past} />
              </section>
            )}
          </div>
        </PageTransition>
      )}
    </AppShell>
  )
}
