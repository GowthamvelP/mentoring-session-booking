import apiClient from './client'
import type { Mentor, PaginatedResponse } from './types'

export async function getMentors(page = 1): Promise<PaginatedResponse<Mentor>> {
  const { data } = await apiClient.get('/mentors', { params: { page } })
  return data
}
