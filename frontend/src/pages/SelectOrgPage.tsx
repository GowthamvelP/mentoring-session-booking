import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { getOrganizations, selectOrganization } from '../api/organizations'
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
  const [userId, setUserId] = useState('')
  const [isSelecting, setIsSelecting] = useState(false)

  const { data: organizations, isLoading, isError, refetch } = useQuery({
    queryKey: QUERY_KEYS.organizations,
    queryFn: getOrganizations,
    staleTime: STALE_TIMES.organizations,
  })

  const handleSelectOrg = async () => {
    if (!selectedOrgId || !userId.trim()) return

    const org = organizations?.find((o) => o.id === selectedOrgId)
    if (!org) return

    setIsSelecting(true)
    try {
      const response = await selectOrganization(org.id, userId.trim())
      const userName = response?.user?.name || response?.user?.email || userId.trim()
      setAuth(org, userId.trim(), userName)
      showToast(`Welcome to ${org.name}`, 'success')
      navigate('/mentors')
    } catch {
      showToast('Failed to authenticate. Check your User ID.', 'error')
    } finally {
      setIsSelecting(false)
    }
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
        <div className="mb-8 text-center">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-xl bg-primary shadow-lg shadow-primary/30">
            <span className="text-xl font-bold text-white">M</span>
          </div>
          <h1 className="text-2xl font-bold text-text">Welcome to MentorBook</h1>
          <p className="mt-2 text-sm text-text-muted">Select your organization and enter your User ID to continue</p>
        </div>

        <div className="space-y-3">
          {organizations?.map((org) => (
            <Card
              key={org.id}
              hover
              onClick={() => setSelectedOrgId(org.id)}
              className={`${
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
                  <p className="mt-0.5 text-xs text-text-dim">Timezone: {org.timezone}</p>
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

        {selectedOrgId && (
          <div className="mt-6 space-y-4">
            <div>
              <label htmlFor="userId" className="block text-sm font-medium text-text-muted mb-1.5">
                User ID
              </label>
              <input
                id="userId"
                type="text"
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
                placeholder="Enter your user ID (UUID)"
                className="w-full rounded-md border border-surface-border bg-surface px-4 py-2.5 text-sm text-text placeholder:text-text-dim focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary transition-colors"
                onKeyDown={(e) => e.key === 'Enter' && handleSelectOrg()}
              />
            </div>
            <Button
              className="w-full"
              size="lg"
              onClick={handleSelectOrg}
              loading={isSelecting}
              disabled={!userId.trim()}
            >
              Continue
            </Button>
          </div>
        )}
      </div>
    </div>
  )
}
