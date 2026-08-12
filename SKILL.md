# MentorBook Mentoring Booking System — Agent Skill

## System Overview
Rails 8 API-only backend for a multi-tenant mentoring session booking platform.
React 19 + Vite SPA frontend. Sidekiq + Redis for async jobs. PostgreSQL 16 with pg_trgm.

## Architecture Rules
1. **Controllers are thin.** They validate params, call Services, render via Blueprinter serializers.
2. **All business logic lives in `app/services/`.** Never put logic in models beyond validations/associations.
3. **Pessimistic locking on slot mutations.** `SELECT FOR UPDATE` in transactions. No optimistic lock_version.
4. **Idempotency is mandatory for bookings.** Always check `idempotency_key` (UNIQUE constraint) before creation.
5. **Multi-tenancy via acts_as_tenant.** Enforced at model layer. Never bypass scoping.
6. **Cache invalidation is pattern-based.** On slot mutation: `Rails.cache.delete_matched("slots:#{mentor_id}:*")`.
7. **Sidekiq jobs use weighted queues.** Critical > Default > AI. All jobs are idempotent.
8. **Search uses pg_trgm GIN indexes.** Trigram similarity for names, ILIKE on unnested arrays for expertise.

## File Organization
- `app/controllers/api/v1/` — Versioned API controllers (inherit from BaseController)
- `app/services/` — Business logic (BookingService, CancellationService, RescheduleService, SlotService)
- `app/services/concerns/` — Shared behavior (CacheInvalidation)
- `app/serializers/` — Blueprinter serializers (*_blueprint.rb)
- `app/jobs/` — Sidekiq jobs (BookingConfirmationJob, BookingCancellationJob, BookingRescheduleJob)
- `app/middleware/` — Rack middleware (CorrelationIdMiddleware)
- `app/models/` — ActiveRecord models with acts_as_tenant
- `db/migrate/` — Strong Migrations validated, concurrent index creation

## Common Tasks

### Adding a New Endpoint
1. Controller action in `Api::V1::*Controller` (inherit from BaseController)
2. Service class in `app/services/` with `.call` class method
3. Serializer in `app/serializers/` using Blueprinter
4. Route in `config/routes.rb` under `namespace :api { namespace :v1 { ... } }`
5. Request spec in `spec/requests/`

### Modifying Slot Status
- Never update `slots` directly from controllers.
- Always go through `BookingService` or `RescheduleService`.
- Use `Slot.lock("FOR UPDATE")` inside transactions.
- Include CacheInvalidation concern for post-commit cache clearing.

### Adding a Background Job
```ruby
class MyJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(record_id)
    # idempotent implementation — check state before acting
  end
end
```

### Database Conventions
- UUID primary keys via `pgcrypto` (gen_random_uuid)
- Indexed foreign keys with `type: :uuid`
- GIN indexes for search (pg_trgm on names, GIN on arrays)
- Composite unique indexes: `[mentor_id, start_time]`, `[org_id, email]`
- Status fields use string-backed enums (not integers)
- `algorithm: :concurrently` with `disable_ddl_transaction!` for production-safe migrations

## Testing
- Run all specs: `cd backend && bundle exec rspec`
- Run specific file: `bundle exec rspec spec/requests/bookings_spec.rb`
- Coverage: SimpleCov with 90% threshold
- Load tests: `cd load-tests && bash run-dev.sh` (requires k6)
- Factories: FactoryBot with traits (`:mentor`, `:member`, `:confirmed`)

## Style Guide
- RuboCop with rubocop-rails-omakase (double quotes, spaces in arrays)
- Lograge for structured JSON logging
- Correlation IDs via X-Request-Id header

## AI Features
- AI Context API at `GET /api/v1/ai/context`
- MCP Server at `GET /api/v1/ai/mcp/tools` + `POST /api/v1/ai/mcp/call`
- Pre-session brief generation via BookingBriefJob (documented architecture)
- Mentor semantic matching via pgvector (documented architecture)
