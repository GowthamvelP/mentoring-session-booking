import { createContext, useState, useCallback } from 'react'
import type { ReactNode } from 'react'
import type { Organization } from '../api/types'
import { apiClient } from '../api/client'

interface AuthState {
  organization: Organization | null
  userId: string | null
}

interface AuthContextValue extends AuthState {
  selectOrganization: (org: Organization, userId: string) => void
  clearAuth: () => void
}

export const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>({ organization: null, userId: null })

  const selectOrganization = useCallback((org: Organization, userId: string) => {
    setAuth({ organization: org, userId })
    apiClient.defaults.headers.common['X-Org-Id'] = org.id
    apiClient.defaults.headers.common['X-User-Id'] = userId
  }, [])

  const clearAuth = useCallback(() => {
    setAuth({ organization: null, userId: null })
    delete apiClient.defaults.headers.common['X-Org-Id']
    delete apiClient.defaults.headers.common['X-User-Id']
  }, [])

  return (
    <AuthContext.Provider value={{ ...auth, selectOrganization, clearAuth }}>
      {children}
    </AuthContext.Provider>
  )
}
