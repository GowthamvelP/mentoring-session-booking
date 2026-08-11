import { Button } from '../ui/Button'

interface WeekNavigationProps {
  currentDate: Date
  onPrevious: () => void
  onNext: () => void
}

export function WeekNavigation({ currentDate, onPrevious, onNext }: WeekNavigationProps) {
  const formattedDate = currentDate.toLocaleDateString(undefined, {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  })

  return (
    <div className="flex items-center justify-between py-4">
      <Button variant="secondary" size="sm" onClick={onPrevious} aria-label="Previous week">
        &larr; Previous
      </Button>
      <span className="text-sm font-medium text-text-muted">Week of {formattedDate}</span>
      <Button variant="secondary" size="sm" onClick={onNext} aria-label="Next week">
        Next &rarr;
      </Button>
    </div>
  )
}
