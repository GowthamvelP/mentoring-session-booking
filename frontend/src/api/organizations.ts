import apiClient from './client'
import type { Organization } from './types'

export async function getOrganizations(): Promise<Organization[]> {
  const { data } = await apiClient.get('/organizations')
  return data
}

export async function selectOrganization(organizationId: string, userId: string) {
  const { data } = await apiClient.post('/auth/select-org', {
    organization_id: organizationId,
    user_id: userId,
  })
  return data
}
