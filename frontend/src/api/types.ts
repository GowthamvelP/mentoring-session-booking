export interface Organization {
  id: string
  name: string
  timezone: string
}

export interface Mentor {
  id: string
  name: string
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
  slot: Slot
  mentor_name: string
  member_name: string
  booked_at: string
  cancelled_at: string | null
}

export interface ApiError {
  error: string
  details?: Record<string, unknown>
}

export interface PaginatedResponse<T> {
  data: T[]
  meta: {
    page: number
    items: number
    count: number
    pages: number
  }
}
