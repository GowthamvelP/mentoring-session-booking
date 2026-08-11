# Backend — Rails 8 API

Ruby on Rails 8.1.3 API-only application serving the mentoring session booking API.

## Setup

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
```

## Run

```bash
# API server
bundle exec puma -C config/puma.rb

# Background jobs (separate terminal)
bundle exec sidekiq
```

## Test

```bash
bundle exec rspec                    # Full suite (144 specs)
bundle exec rspec --tag concurrency  # Just concurrency tests
bundle exec brakeman                 # Security scan
bundle exec bundler-audit check      # Dependency audit
bundle exec rubocop                  # Linting
```

## Key Architecture

- **Services**: `app/services/` — BookingService, CancellationService, RescheduleService, SlotService
- **Models**: `app/models/` — Organization, User, MentorProfile, Slot, Booking, Current
- **Serializers**: `app/serializers/` — Blueprinter-based API contracts
- **Jobs**: `app/jobs/` — Sidekiq background jobs (confirmation, cancellation, reschedule)
- **Middleware**: `app/middleware/` — CorrelationIdMiddleware

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| DATABASE_URL | PostgreSQL connection | postgresql://mentoring:mentoring@localhost:5432/mentoring_development |
| REDIS_URL | Redis for cache + Sidekiq | redis://localhost:6379/0 |
| SECRET_KEY_BASE | Rails secret key | (generated) |
| RAILS_ENV | Environment | development |
