import { Link, useLocation } from 'react-router-dom'
import { useAuth } from '../../hooks/useAuth'

export function Navbar() {
  const { organization, userName, clearAuth, isAuthenticated } = useAuth()
  const location = useLocation()

  const isActive = (path: string) => location.pathname.startsWith(path)

  const linkClass = (path: string) =>
    `text-sm font-medium transition-colors ${
      isActive(path)
        ? 'text-primary-light'
        : 'text-text-muted hover:text-text'
    }`

  return (
    <nav className="sticky top-0 z-40 border-b border-surface-border bg-surface-card/80 backdrop-blur-md" aria-label="Main navigation">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        <Link to="/mentors" className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-md bg-primary">
            <span className="text-sm font-bold text-white">M</span>
          </div>
          <span className="text-lg font-semibold text-text">MentorBook</span>
        </Link>

        {isAuthenticated && (
          <div className="flex items-center gap-8">
            <div className="flex items-center gap-6">
              <Link to="/mentors" className={linkClass('/mentors')}>
                Mentors
              </Link>
              <Link to="/sessions" className={linkClass('/sessions')}>
                My Sessions
              </Link>
            </div>

            <div className="flex items-center gap-3 border-l border-surface-border pl-6">
              <div className="text-right">
                <p className="text-xs text-text-dim">{organization?.name}</p>
                <p className="text-sm text-text-muted">{userName || 'User'}</p>
              </div>
              <button
                onClick={clearAuth}
                className="rounded-md p-1.5 text-text-dim hover:bg-surface-hover hover:text-text transition-colors"
                aria-label="Sign out"
                title="Switch organization"
              >
                <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
                  />
                </svg>
              </button>
            </div>
          </div>
        )}
      </div>
    </nav>
  )
}
