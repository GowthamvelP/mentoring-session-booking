import axios from 'axios'
import type { ApiError } from './types'
import { API_BASE_URL } from '../lib/constants'

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: { 'Content-Type': 'application/json' },
})

apiClient.interceptors.request.use((config) => {
  const userId = localStorage.getItem('userId')
  const orgId = localStorage.getItem('orgId')
  if (userId) config.headers['X-User-Id'] = userId
  if (orgId) config.headers['X-Org-Id'] = orgId
  return config
})

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    const apiError: ApiError = {
      error: error.response?.data?.error || 'Network error',
      details: error.response?.data?.details,
      status: error.response?.status,
    }
    return Promise.reject(apiError)
  }
)

export default apiClient
