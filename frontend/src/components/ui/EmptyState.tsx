import type { ReactNode } from 'react'

interface EmptyStateProps {
  title: string
  description?: string
  icon?: ReactNode
  action?: ReactNode
}

export function EmptyState({ title, description, icon, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-20 text-center">
      {icon && <div className="mb-4 text-text-dim">{icon}</div>}
      <h3 className="text-lg font-medium text-text-muted">{title}</h3>
      {description && <p className="mt-2 max-w-sm text-sm text-text-dim">{description}</p>}
      {action && <div className="mt-6">{action}</div>}
    </div>
  )
}
