import { createContext, useState, useCallback, useEffect } from 'react'
import type { ReactNode } from 'react'
import type { Organization } from '../api/types'
import { getBrowserTimezone } from '../lib/dates'

interface AuthState {
  organization: Organization | null
  userId: string | null
  userName: string | null
  timezone: string
}

interface AuthContextValue extends AuthState {
  selectOrganization: (org: Organization, userId: string, userName?: string) => void
  clearAuth: () => void
  setTimezone: (tz: string) => void
  isAuthenticated: boolean
}

export const AuthContext = createContext<AuthContextValue | null>(null)

function loadPersistedAuth(): AuthState {
  try {
    const orgData = localStorage.getItem('organization')
    const userId = localStorage.getItem('userId')
    const userName = localStorage.getItem('userName')
    const timezone = localStorage.getItem('timezone') || getBrowserTimezone()
    return {
      organization: orgData ? JSON.parse(orgData) : null,
      userId,
      userName,
      timezone,
    }
  } catch {
    return { organization: null, userId: null, userName: null, timezone: getBrowserTimezone() }
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>(loadPersistedAuth)

  useEffect(() => {
    if (auth.organization) {
      localStorage.setItem('organization', JSON.stringify(auth.organization))
      localStorage.setItem('orgId', auth.organization.id)
    }
    if (auth.userId) {
      localStorage.setItem('userId', auth.userId)
    }
    if (auth.userName) {
      localStorage.setItem('userName', auth.userName)
    }
    if (auth.timezone) {
      localStorage.setItem('timezone', auth.timezone)
    }
  }, [auth])

  const selectOrganization = useCallback((org: Organization, userId: string, userName?: string) => {
    setAuth((prev) => ({ ...prev, organization: org, userId, userName: userName || null }))
  }, [])

  const setTimezone = useCallback((tz: string) => {
    setAuth((prev) => ({ ...prev, timezone: tz }))
  }, [])

  const clearAuth = useCallback(() => {
    setAuth({ organization: null, userId: null, userName: null, timezone: getBrowserTimezone() })
    localStorage.removeItem('organization')
    localStorage.removeItem('orgId')
    localStorage.removeItem('userId')
    localStorage.removeItem('userName')
    localStorage.removeItem('timezone')
  }, [])

  return (
    <AuthContext.Provider value={{ ...auth, selectOrganization, clearAuth, setTimezone, isAuthenticated: !!auth.userId && !!auth.organization }}>
      {children}
    </AuthContext.Provider>
  )
}
