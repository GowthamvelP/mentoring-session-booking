interface ToastProps {
  message: string
  variant?: 'success' | 'error' | 'info'
  onClose: () => void
}

export function Toast({ message, variant = 'info', onClose }: ToastProps) {
  const variants = {
    success: 'bg-success/20 border-success text-success',
    error: 'bg-danger/20 border-danger text-danger',
    info: 'bg-primary/20 border-primary text-primary-light',
  }

  return (
    <div className={`fixed top-4 right-4 z-50 flex items-center gap-3 rounded-lg border px-4 py-3 shadow-lg ${variants[variant]}`}>
      <span>{message}</span>
      <button onClick={onClose} className="ml-2 text-current opacity-70 hover:opacity-100" aria-label="Close">
        &times;
      </button>
    </div>
  )
}
