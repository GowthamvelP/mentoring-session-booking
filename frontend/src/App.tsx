import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Routes, Route } from 'react-router-dom'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 2,
      refetchOnWindowFocus: true,
    },
  },
})

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <div className="min-h-screen bg-surface font-sans">
          <Routes>
            <Route path="/" element={<div className="p-8 text-text">Select Organization</div>} />
            <Route path="/mentors" element={<div className="p-8 text-text">Mentors</div>} />
            <Route path="/mentors/:id/slots" element={<div className="p-8 text-text">Slots</div>} />
            <Route path="/sessions" element={<div className="p-8 text-text">My Sessions</div>} />
          </Routes>
        </div>
      </BrowserRouter>
    </QueryClientProvider>
  )
}

export default App
