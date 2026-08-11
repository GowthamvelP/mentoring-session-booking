import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useMentors } from '../hooks/useMentors'
import { AppShell } from '../components/layout/AppShell'
import { PageHeader } from '../components/layout/PageHeader'
import { MentorGrid } from '../components/mentors/MentorGrid'
import { CardSkeleton } from '../components/ui/Skeleton'
import { EmptyState } from '../components/ui/EmptyState'
import { ErrorState } from '../components/ui/ErrorState'
import { Button } from '../components/ui/Button'
import { PageTransition } from '../components/ui/PageTransition'
import type { Mentor } from '../api/types'

export function MentorsPage() {
  const [page, setPage] = useState(1)
  const { data, isLoading, isError, refetch } = useMentors(page)
  const navigate = useNavigate()

  const handleMentorClick = (mentor: Mentor) => {
    navigate(`/mentors/${mentor.id}/slots`)
  }

  return (
    <AppShell>
      <PageHeader
        title="Browse Mentors"
        description="Find a mentor and book a session with them"
      />

      {isLoading && (
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <CardSkeleton key={i} />
          ))}
        </div>
      )}

      {isError && (
        <ErrorState message="Failed to load mentors" onRetry={() => refetch()} />
      )}

      {data && data.data.length === 0 && (
        <EmptyState
          title="No mentors available"
          description="There are no mentors in your organization yet."
          icon={
            <svg className="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          }
        />
      )}

      {data && data.data.length > 0 && (
        <PageTransition>
          <MentorGrid mentors={data.data} onMentorClick={handleMentorClick} />

          {data.meta.total_pages > 1 && (
            <div className="mt-8 flex items-center justify-center gap-3">
              <Button
                variant="secondary"
                size="sm"
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page === 1}
              >
                Previous
              </Button>
              <span className="text-sm text-text-muted">
                Page {data.meta.current_page} of {data.meta.total_pages}
              </span>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => setPage((p) => p + 1)}
                disabled={page >= data.meta.total_pages}
              >
                Next
              </Button>
            </div>
          )}
        </PageTransition>
      )}
    </AppShell>
  )
}
