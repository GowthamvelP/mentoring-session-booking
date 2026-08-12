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
- **Hooks** (`src/hooks/`): TanStack Query hooks with optimistic updates, cache invalidation
- **Components** (`src/components/`): Composable UI primitives (dark theme)
- **Pages** (`src/pages/`): 5 pages (OrgSelect, Mentors, MentorSlots, MySessions)
- **Context** (`src/context/`): Auth state + Toast notifications

## Pages

| Page | Route | Features |
|------|-------|----------|
| OrgSelectPage | `/` | Organization + user selection |
| MentorsPage | `/mentors` | Browse mentors, GIN trigram search, pagination |
| MentorSlotsPage | `/mentors/:id/slots` | Week navigation, timezone selector, booking + reschedule |
| MySessionsPage | `/sessions` | Upcoming/past sessions, cancel, reschedule navigation |

## Key Components

### Booking Flow
- **ConfirmBookingModal** — Pre-booking confirmation (reusable for reschedule)
- **BookingConfirmationModal** — Post-booking success with Add to Calendar (Google + .ics)
- **CancelConfirmModal** — Cancel confirmation with warning

### Notifications
- **NotificationBell** — Navbar bell icon with unread badge, dropdown panel
- Real-time via synchronous backend creation + TanStack Query invalidation
- Background polling every 30s for cross-user updates

### Timezone
- **TimezoneSelector** — Full IANA timezone list via `@vvo/tzdb`
- Per-booking timezone storage (doesn't drift with user settings)
- All times displayed using native `Intl.DateTimeFormat`

## Design System

Dark theme with custom Tailwind properties:
- Surface: `#0f172a` (slate-900)
- Primary: `#6366f1` (indigo-500)
- Accent: `#22d3ee` (cyan-400)
- Text: `#f8fafc` / `#94a3b8` / `#64748b`
- Danger: `#ef4444` (red-500)
- Warning: `#f59e0b` (amber-500)

## Key Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| React | 19 | UI framework |
| TanStack Query | v5 | Server state, caching, optimistic updates |
| React Router | v6 | Client-side routing |
| @vvo/tzdb | latest | IANA timezone database |
| date-fns | latest | Date arithmetic (week navigation) |
| Tailwind CSS | v4 | Utility-first styling |
| Vite | v8 | Build tool + HMR |
| Vitest | v4 | Unit testing |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| VITE_API_URL | Backend API base URL | http://localhost:3000/api/v1 |
