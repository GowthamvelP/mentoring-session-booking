import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import apiClient from "../api/client"
import { QUERY_KEYS } from "../lib/constants"

interface Notification {
  id: string
  type: string
  title: string
  body: string
  read: boolean
  booking_id: string | null
  created_at: string
}

interface NotificationsResponse {
  data: Notification[]
  unread_count: number
}

async function getNotifications(): Promise<NotificationsResponse> {
  const { data } = await apiClient.get("/notifications")
  return data
}

async function markNotificationRead(id: string): Promise<void> {
  await apiClient.patch(`/notifications/${id}/mark_read`)
}

async function markAllRead(): Promise<void> {
  await apiClient.post("/notifications/mark_all_read")
}

export function useNotifications() {
  return useQuery({
    queryKey: QUERY_KEYS.notifications,
    queryFn: getNotifications,
    staleTime: 0, // Always refetch when invalidated — notifications must be real-time
    refetchInterval: 30_000, // Background poll every 30s for external changes
  })
}

export function useMarkNotificationRead() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: markNotificationRead,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.notifications })
    },
  })
}

export function useMarkAllNotificationsRead() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: markAllRead,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.notifications })
    },
  })
}
