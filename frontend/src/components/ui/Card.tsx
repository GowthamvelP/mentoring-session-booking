import type { HTMLAttributes } from 'react'

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  hover?: boolean
}

export function Card({ children, hover = false, className = '', ...props }: CardProps) {
  const base = 'rounded-lg border border-surface-border bg-surface-card p-6 shadow-sm'
  const hoverClass = hover
    ? 'hover:border-primary/50 hover:shadow-md hover:shadow-primary/5 transition-all duration-200 cursor-pointer'
    : ''

  return (
    <div className={`${base} ${hoverClass} ${className}`} {...props}>
      {children}
    </div>
  )
}
