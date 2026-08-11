import type { Mentor } from '../../api/types'
import { MentorCard } from './MentorCard'

interface MentorGridProps {
  mentors: Mentor[]
  onMentorClick?: (mentor: Mentor) => void
}

export function MentorGrid({ mentors, onMentorClick }: MentorGridProps) {
  return (
    <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 animate-stagger">
      {mentors.map((mentor) => (
        <MentorCard
          key={mentor.id}
          mentor={mentor}
          onClick={() => onMentorClick?.(mentor)}
        />
      ))}
    </div>
  )
}
