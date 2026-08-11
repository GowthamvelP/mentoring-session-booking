import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { getOrganizations, getOrganizationUsers } from '../api/organizations'
import { useAuth } from '../hooks/useAuth'
import { QUERY_KEYS, STALE_TIMES } from '../lib/constants'
import { Card } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { Skeleton } from '../components/ui/Skeleton'
import { ErrorState } from '../components/ui/ErrorState'
import { useToast } from '../context/ToastContext'

export function SelectOrgPage() {
  const navigate = useNavigate()
  const { selectOrganization: setAuth } = useAuth()
  const { showToast } = useToast()
  const [selectedOrgId, setSelectedOrgId] = useState<string | null>(null)
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null)

  const { data: organizations, isLoading, isError, refetch } = useQuery({
    queryKey: QUERY_KEYS.organizations,
    queryFn: getOrganizations,
    staleTime: STALE_TIMES.organizations,
  })

  // Fetch users when an org is selected
  const { data: users, isLoading: isLoadingUsers } = useQuery({
    queryKey: ['org-users', selectedOrgId],
    queryFn: () => getOrganizationUsers(selectedOrgId!),
    enabled: !!selectedOrgId,
    staleTime: STALE_TIMES.organizations,
  })

  const handleContinue = () => {
    if (!selectedOrgId || !selectedUserId) return

    const org = organizations?.find((o) => o.id === selectedOrgId)
    const user = users?.find((u) => u.id === selectedUserId)
    if (!org || !user) return

    setAuth(org, user.id, user.name)
    showToast(`Welcome, ${user.name}!`, 'success')
    navigate('/mentors')
  }

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-surface px-4">
        <div className="w-full max-w-lg space-y-4">
          <Skeleton className="h-8 w-48 mx-auto" />
          <Skeleton className="h-24 rounded-lg" />
          <Skeleton className="h-24 rounded-lg" />
        </div>
      </div>
    )
  }

  if (isError) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-surface px-4">
        <ErrorState message="Failed to load organizations" onRetry={() => refetch()} />
      </div>
    )
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-surface px-4">
      <div className="w-full max-w-lg">
        {/* Header */}
        <div className="mb-8 text-center">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-xl bg-primary shadow-lg shadow-primary/30">
            <span className="text-xl font-bold text-white">M</span>
          </div>
          <h1 className="text-2xl font-bold text-text">Welcome to MentorBook</h1>
          <p className="mt-2 text-sm text-text-muted">Select your organization and user to continue</p>
        </div>

        {/* Step 1: Organization selection */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-text-muted mb-3">Organization</label>
          <div className="space-y-3">
            {organizations?.map((org) => (
              <Card
                key={org.id}
                hover
                onClick={() => { setSelectedOrgId(org.id); setSelectedUserId(null) }}
                className={`cursor-pointer transition-all ${
                  selectedOrgId === org.id
                    ? 'border-primary bg-primary/5 ring-1 ring-primary/30'
                    : ''
                }`}
                role="radio"
                aria-checked={selectedOrgId === org.id}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="font-semibold text-text">{org.name}</h3>
                    <p className="mt-0.5 text-xs text-text-dim">{org.timezone}</p>
                  </div>
                  <div
                    className={`h-5 w-5 rounded-full border-2 transition-colors ${
                      selectedOrgId === org.id
                        ? 'border-primary bg-primary'
                        : 'border-surface-border'
                    }`}
                  >
                    {selectedOrgId === org.id && (
                      <svg className="h-full w-full text-white p-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                      </svg>
                    )}
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </div>

        {/* Step 2: User selection (appears after org is picked) */}
        {selectedOrgId && (
          <div className="mb-6">
            <label className="block text-sm font-medium text-text-muted mb-2">Sign in as</label>
            {isLoadingUsers ? (
              <Skeleton className="h-12 rounded-md" />
            ) : (
              <div className="space-y-2">
                {users?.map((user) => (
                  <button
                    key={user.id}
                    onClick={() => setSelectedUserId(user.id)}
                    className={`w-full flex items-center gap-3 rounded-lg border px-4 py-3 text-left transition-all ${
                      selectedUserId === user.id
                        ? 'border-primary bg-primary/5 ring-1 ring-primary/30'
                        : 'border-surface-border bg-surface-card hover:border-surface-hover'
                    }`}
                  >
                    {/* Avatar */}
                    <div className={`flex h-9 w-9 items-center justify-center rounded-full text-sm font-semibold ${
                      user.role === 'mentor' ? 'bg-accent/20 text-accent' : 'bg-primary/20 text-primary-light'
                    }`}>
                      {user.name.charAt(0)}
                    </div>
                    {/* User info */}
                    <div className="flex-1">
                      <div className="text-sm font-medium text-text">{user.name}</div>
                      <div className="text-xs text-text-dim">{user.email}</div>
                    </div>
                    {/* Role badge */}
                    <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      user.role === 'mentor'
                        ? 'bg-accent/10 text-accent'
                        : 'bg-primary/10 text-primary-light'
                    }`}>
                      {user.role}
                    </span>
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Continue button */}
        {selectedUserId && (
          <Button className="w-full" size="lg" onClick={handleContinue}>
            Continue
          </Button>
        )}
      </div>
    </div>
  )
}
