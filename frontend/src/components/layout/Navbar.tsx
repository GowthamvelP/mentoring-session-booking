import { Link } from 'react-router-dom'

export function Navbar() {
  return (
    <nav className="border-b border-surface-border bg-surface-card" aria-label="Main navigation">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        <Link to="/mentors" className="text-lg font-semibold text-text">
          MentorBook
        </Link>
        <div className="flex items-center gap-6">
          <Link to="/mentors" className="text-sm text-text-muted hover:text-text transition-colors">
            Mentors
          </Link>
          <Link to="/sessions" className="text-sm text-text-muted hover:text-text transition-colors">
            My Sessions
          </Link>
        </div>
      </div>
    </nav>
  )
}
