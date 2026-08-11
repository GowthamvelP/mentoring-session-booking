import { useState, useEffect, useRef } from 'react'
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

function useDebounce(value: string, delay: number): string {
  const [debouncedValue, setDebouncedValue] = useState(value)

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay)
    return () => clearTimeout(timer)
  }, [value, delay])

  return debouncedValue
}

export function MentorsPage() {
  const [page, setPage] = useState(1)
  const [searchInput, setSearchInput] = useState('')
  const debouncedSearch = useDebounce(searchInput, 300)
  const inputRef = useRef<HTMLInputElement>(null)
  const navigate = useNavigate()

  // Reset page when search changes
  useEffect(() => {
    setPage(1)
  }, [debouncedSearch])

  const { data, isLoading, isFetching, isError, refetch } = useMentors(page, debouncedSearch)

  const handleMentorClick = (mentor: Mentor) => {
    navigate(`/mentors/${mentor.id}/slots`)
  }

  const isSearching = searchInput !== debouncedSearch || (isFetching && !!debouncedSearch)

  return (
    <AppShell>
      <PageHeader
        title="Browse Mentors"
        description="Find a mentor and book a session with them"
      />

      {/* Search Input */}
      <div className="mb-6 w-full max-w-md">
        <div className="relative">
          <svg
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-dim"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
          <input
            ref={inputRef}
            type="text"
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Search by name or expertise..."
            className="w-full rounded-lg border border-surface-border bg-surface-card py-2.5 pl-10 pr-10 text-sm text-text placeholder-text-dim transition-colors focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            aria-label="Search mentors"
          />
          {searchInput && (
            <button
              onClick={() => {
                setSearchInput('')
                inputRef.current?.focus()
              }}
              className="absolute right-3 top-1/2 -translate-y-1/2 rounded p-0.5 text-text-dim transition-colors hover:text-text"
              aria-label="Clear search"
            >
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          )}
        </div>
        {isSearching && (
          <p className="mt-1.5 text-xs text-text-muted">Searching...</p>
        )}
      </div>

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
          title={debouncedSearch ? 'No mentors found' : 'No mentors available'}
          description={
            debouncedSearch
              ? `No mentors match "${debouncedSearch}". Try a different search term.`
              : 'There are no mentors in your organization yet.'
          }
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
