import { apiClient } from './client'
import type { Booking, PaginatedResponse } from './types'

export async function getMySessions(page = 1): Promise<PaginatedResponse<Booking>> {
  const { data } = await apiClient.get('/me/sessions', { params: { page } })
  return data
}

export async function getMyMentorSessions(page = 1): Promise<PaginatedResponse<Booking>> {
  const { data } = await apiClient.get('/me/mentor_sessions', { params: { page } })
  return data
}
