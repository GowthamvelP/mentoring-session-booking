export interface Organization {
  id: string
  name: string
  timezone: string
}

export interface Mentor {
  id: string
  name: string
  email: string
  role: string
  bio: string
  expertise: string[]
}

export interface Slot {
  id: string
  start_time: string
  end_time: string
  status: 'available' | 'booked'
}

export interface Booking {
  id: string
  status: 'confirmed' | 'cancelled' | 'completed'
  booked_at: string
  cancelled_at: string | null
  slot: {
    id: string
    start_time: string
    end_time: string
  }
  mentor?: {
    id: string
    name: string
    expertise: string[]
  }
  member?: {
    id: string
    name: string
    email: string
  }
}

export interface ApiError {
  error: string
  details?: Record<string, string>
  status?: number
}

export interface PaginationMeta {
  current_page: number
  total_pages: number
  total_count: number
  per_page: number
}

export interface PaginatedResponse<T> {
  data: T[]
  meta: PaginationMeta
}
