import type { Mentor } from '../../api/types'
import { Card } from '../ui/Card'
import { Badge } from '../ui/Badge'

interface MentorCardProps {
  mentor: Mentor
  onClick?: () => void
}

export function MentorCard({ mentor, onClick }: MentorCardProps) {
  return (
    <Card hover onClick={onClick} role="article" aria-label={`Mentor: ${mentor.name}`}>
      <h3 className="text-lg font-semibold text-text">{mentor.name}</h3>
      <p className="mt-1 text-sm text-text-muted line-clamp-2">{mentor.bio}</p>
      <div className="mt-3 flex flex-wrap gap-2">
        {mentor.expertise.map((skill) => (
          <Badge key={skill}>{skill}</Badge>
        ))}
      </div>
    </Card>
  )
}
