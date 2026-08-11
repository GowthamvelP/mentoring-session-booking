interface EmptyStateProps {
  title: string
  description?: string
}

export function EmptyState({ title, description }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <h3 className="text-lg font-medium text-text-muted">{title}</h3>
      {description && <p className="mt-2 text-sm text-text-dim">{description}</p>}
    </div>
  )
}
