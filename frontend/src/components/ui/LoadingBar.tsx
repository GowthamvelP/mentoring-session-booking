import { useIsFetching, useIsMutating } from '@tanstack/react-query'

export function LoadingBar() {
  const isFetching = useIsFetching()
  const isMutating = useIsMutating()
  const isLoading = isFetching > 0 || isMutating > 0

  if (!isLoading) return null

  return (
    <div className="loading-bar" />
  )
}
