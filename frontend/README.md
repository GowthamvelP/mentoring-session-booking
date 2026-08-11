# Frontend — React 19 + Vite + Tailwind

A React single-page application with a dark theme design system for the mentoring session booking platform.

## Setup

```bash
npm install
```

## Run

```bash
npm run dev          # Development server (http://localhost:5173)
npm run build        # Production build
npm run preview      # Preview production build
npm run test         # Run tests (watch mode)
npm run test:run     # Run tests (CI mode)
```

## Architecture

- **API Layer** (`src/api/`): Typed Axios client with auth header injection
- **Hooks** (`src/hooks/`): TanStack Query hooks with optimistic updates
- **Components** (`src/components/`): Composable UI primitives (dark theme)
- **Pages** (`src/pages/`): 4 main pages composing hooks + components
- **Context** (`src/context/`): Auth state + Toast notifications

## Design System

Dark theme with custom properties:
- Surface: `#0f172a` (slate-900)
- Primary: `#6366f1` (indigo-500)
- Accent: `#22d3ee` (cyan-400)
- Text: `#f8fafc` / `#94a3b8` / `#64748b`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| VITE_API_URL | Backend API base URL | http://localhost:3000/api/v1 |
