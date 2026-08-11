import apiClient from './client'
import type { Mentor, PaginatedResponse } from './types'

export async function getMentors(page = 1, search?: string): Promise<PaginatedResponse<Mentor>> {
  const params: Record<string, string | number> = { page }
  if (search && search.trim()) {
    params.search = search.trim()
  }
  const { data } = await apiClient.get('/mentors', { params })
  return data
}
