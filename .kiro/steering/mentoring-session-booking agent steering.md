---
inclusion: always
---

# Mentoring Session Booking — Project Conventions

## Stack

- **Backend**: Rails 8.1.3 (API-only), PostgreSQL 16, Redis 7, Sidekiq 7, Puma
- **Frontend**: React 19, TypeScript 6, Vite 8, Tailwind CSS 4, TanStack Query v5
- **Testing**: RSpec + FactoryBot (backend), Vitest + React Testing Library + MSW (frontend), k6 (load)
- **Infra**: Docker Compose (postgres, redis, backend, sidekiq, frontend)

## Architecture Rules

1. **Controllers are thin.** Validate params, call a service, render via Blueprinter serializer. No business logic.
2. **Business logic lives in `app/services/`.** Services expose a `.call` class method and return `{ success:, booking:/error:, status: }`.
3. **Models hold only validations, associations, scopes, and enums.** No business logic in models.
4. **Multi-tenancy via `acts_as_tenant`.** Never bypass tenant scoping. All tenant-scoped models declare `acts_as_tenant :organization`.
5. **Pessimistic locking for slot mutations.** Use `Slot.lock("FOR UPDATE")` inside transactions. No optimistic locking.
6. **Idempotency is mandatory for bookings.** Always require and check `idempotency_key` (DB unique constraint) before creation.
7. **Cache invalidation is pattern-based.** After slot mutations: `Rails.cache.delete_matched("slots:#{mentor_id}:*")`.
8. **Sidekiq jobs must be idempotent.** Weighted queues: critical > default > notifications > ai > low.
9. **UUID primary keys** via `pgcrypto` (`gen_random_uuid`). String-backed enums, not integers.
10. **Strong Migrations** validates all schema changes. Use `algorithm: :concurrently` with `disable_ddl_transaction!` for index creation.

## Backend Conventions

### File Organization

| Directory | Purpose |
|-----------|---------|
| `app/controllers/api/v1/` | Versioned API controllers (inherit `BaseController`) |
| `app/services/` | Service objects with `.call` class method |
| `app/services/concerns/` | Shared service behaviors (`CacheInvalidation`) |
| `app/serializers/` | Blueprinter serializers (`*_blueprint.rb`) |
| `app/jobs/` | Sidekiq background jobs |
| `app/middleware/` | Rack middleware (`CorrelationIdMiddleware`) |
| `app/controllers/concerns/` | Controller concerns (`Authenticatable`, `Tenantable`) |

### Adding a New Endpoint

1. Controller action in `Api::V1::*Controller` (inherit from `BaseController`)
2. Service class in `app/services/` with `.call` class method
3. Serializer in `app/serializers/` using Blueprinter
4. Route in `config/routes.rb` under `namespace :api { namespace :v1 { ... } }`
5. Request spec in `spec/requests/`

### Code Style

- `rubocop-rails-omakase` — double quotes, standard Rails conventions
- `# frozen_string_literal: true` at top of every Ruby file
- Lograge for structured JSON logging with correlation IDs
- Consistent error response format: `{ error: String, details?: Object }`
- Pagination via Pagy: `{ data: [], meta: { current_page, total_pages, total_count, per_page } }`

### Authentication

- Header-based stub: `X-User-Id` and `X-Org-Id` request headers
- Handled by `Authenticatable` concern, sets `Current` attributes
- Tenant set by `Tenantable` concern from org header

### Service Object Pattern

```ruby
class MyService
  def self.call(**args)
    new(**args).call
  end

  def call
    # Business logic here
    { success: true, record: record }
  rescue SomeError => e
    { success: false, error: e.message, status: :conflict }
  end
end
```

### Database Conventions

- UUID PKs, indexed UUID foreign keys
- GIN indexes for search (`pg_trgm` on names, GIN on arrays)
- Composite unique indexes where appropriate
- Status fields: string-backed enums

## Frontend Conventions

### File Organization

| Directory | Purpose |
|-----------|---------|
| `src/api/` | Typed Axios client, endpoint functions, `types.ts` |
| `src/hooks/` | TanStack Query hooks (one per domain) |
| `src/components/` | Feature-organized: `ui/`, `layout/`, `mentors/`, `sessions/`, `slots/` |
| `src/pages/` | Page-level components |
| `src/context/` | React Context providers (`AuthContext`, `ToastContext`) |
| `src/lib/` | Utilities (idempotency, dates, constants) |

### Patterns

- **Server state**: TanStack Query v5 — no Redux/Zustand. `staleTime: 30_000`, `retry: 2`.
- **API client**: Axios with request interceptor injecting auth headers, response interceptor transforming errors to typed `ApiError`.
- **Optimistic updates**: On mutations, cancel outgoing queries, snapshot state, update cache, rollback on error.
- **Query keys**: Centralized in `QUERY_KEYS` constant object in `src/lib/constants.ts`.
- **Auth**: React Context + localStorage persistence. Route guards via `RequireAuth`/`RedirectIfAuth` wrappers.
- **Styling**: Tailwind CSS v4 utility classes. Dark theme design system.
- **Linting**: `oxlint` (Rust-based, fast). No Prettier or ESLint.
- **Types**: All API response types defined in `src/api/types.ts`. Use TypeScript strict mode.

### Adding a New Feature (Frontend)

1. Define types in `src/api/types.ts`
2. Add API function in `src/api/`
3. Create TanStack Query hook in `src/hooks/`
4. Build UI components in `src/components/<feature>/`
5. Compose in a page component under `src/pages/`

## Testing

- **Backend**: `cd backend && bundle exec rspec` — 200+ specs, 90%+ coverage (SimpleCov)
- **Frontend**: `cd frontend && npm run test:run` — Vitest with happy-dom, MSW for API mocking
- **Load tests**: `cd load-tests && bash run-dev.sh` — k6 scenarios for concurrency/idempotency/rate-limiting
- **Security**: `brakeman` (static analysis), `bundler-audit` (dependency audit)

## Running the Project

```bash
docker-compose up --build
# Frontend: http://localhost:5173
# Backend API: http://localhost:3000/api/v1
# Sidekiq UI: http://localhost:3000/sidekiq
```

## AI Features

- AI Context API: `GET /api/v1/ai/context` — machine-readable system metadata
- MCP Server: `GET /api/v1/ai/mcp/tools` + `POST /api/v1/ai/mcp/call`
- `BookingBriefJob` on `ai` queue for pre-session briefs
- Search: `pg_trgm` GIN trigram indexes for fuzzy mentor/expertise matching