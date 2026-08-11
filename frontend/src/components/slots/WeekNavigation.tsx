import { format } from 'date-fns'
import { Button } from '../ui/Button'

interface WeekNavigationProps {
  currentDate: Date
  onPrevious: () => void
  onNext: () => void
  disablePrevious?: boolean
}

export function WeekNavigation({ currentDate, onPrevious, onNext, disablePrevious }: WeekNavigationProps) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-surface-border bg-surface-card px-4 py-3">
      <Button variant="ghost" size="sm" onClick={onPrevious} disabled={disablePrevious} aria-label="Previous week">
        <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Prev
      </Button>

      <span className="text-sm font-medium text-text">
        Week of {format(currentDate, 'MMM d, yyyy')}
      </span>

      <Button variant="ghost" size="sm" onClick={onNext} aria-label="Next week">
        Next
        <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
        </svg>
      </Button>
    </div>
  )
}
