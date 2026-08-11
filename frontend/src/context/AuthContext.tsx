import { createContext, useState, useCallback, useEffect } from 'react'
import type { ReactNode } from 'react'
import type { Organization } from '../api/types'

interface AuthState {
  organization: Organization | null
  userId: string | null
  userName: string | null
}

interface AuthContextValue extends AuthState {
  selectOrganization: (org: Organization, userId: string, userName?: string) => void
  clearAuth: () => void
  isAuthenticated: boolean
}

export const AuthContext = createContext<AuthContextValue | null>(null)

function loadPersistedAuth(): AuthState {
  try {
    const orgData = localStorage.getItem('organization')
    const userId = localStorage.getItem('userId')
    const userName = localStorage.getItem('userName')
    return {
      organization: orgData ? JSON.parse(orgData) : null,
      userId,
      userName,
    }
  } catch {
    return { organization: null, userId: null, userName: null }
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
  }, [auth])

  const selectOrganization = useCallback((org: Organization, userId: string, userName?: string) => {
    setAuth({ organization: org, userId, userName: userName || null })
  }, [])

  const clearAuth = useCallback(() => {
    setAuth({ organization: null, userId: null, userName: null })
    localStorage.removeItem('organization')
    localStorage.removeItem('orgId')
    localStorage.removeItem('userId')
    localStorage.removeItem('userName')
  }, [])

  return (
    <AuthContext.Provider value={{ ...auth, selectOrganization, clearAuth, isAuthenticated: !!auth.userId && !!auth.organization }}>
      {children}
    </AuthContext.Provider>
  )
}
