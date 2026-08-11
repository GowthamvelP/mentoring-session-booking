import type { HTMLAttributes } from 'react'

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  hover?: boolean
}

export function Card({ children, hover = false, className = '', ...props }: CardProps) {
  const base = 'rounded-xl border border-surface-border bg-surface-card p-6'
  const hoverClass = hover ? 'hover:bg-surface-hover transition-colors cursor-pointer' : ''

  return (
    <div className={`${base} ${hoverClass} ${className}`} {...props}>
      {children}
    </div>
  )
}
