import { memo } from 'react'
import type { Mentor } from '../../api/types'
import { Card } from '../ui/Card'
import { Badge } from '../ui/Badge'

interface MentorCardProps {
  mentor: Mentor
  onClick?: () => void
}

export const MentorCard = memo(function MentorCard({ mentor, onClick }: MentorCardProps) {
  return (
    <Card hover onClick={onClick} role="article" aria-label={`Mentor: ${mentor.name}`}>
      <div className="flex items-start gap-4">
        <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-primary/15 text-primary-light font-semibold text-lg">
          {mentor.name.charAt(0)}
        </div>
        <div className="min-w-0 flex-1">
          <h3 className="text-base font-semibold text-text truncate">{mentor.name}</h3>
          <p className="text-xs text-text-dim capitalize">{mentor.role}</p>
        </div>
      </div>
      {mentor.bio && (
        <p className="mt-3 text-sm text-text-muted line-clamp-2 leading-relaxed">{mentor.bio}</p>
      )}
      {mentor.expertise.length > 0 && (
        <div className="mt-4 flex flex-wrap gap-1.5">
          {mentor.expertise.slice(0, 4).map((skill) => (
            <Badge key={skill} variant="accent">{skill}</Badge>
          ))}
          {mentor.expertise.length > 4 && (
            <Badge variant="default">+{mentor.expertise.length - 4}</Badge>
          )}
        </div>
      )}
    </Card>
  )
})
