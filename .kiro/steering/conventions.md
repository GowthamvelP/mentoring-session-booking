---
inclusion: auto
---

# Project Conventions

When working in this project:

1. **Ruby style**: rubocop-rails-omakase (double quotes, spaces inside array brackets)
2. **Services pattern**: All business logic in `app/services/`. Controllers are thin.
3. **Pessimistic locking**: Use `Slot.lock("FOR UPDATE")` for slot mutations
4. **Idempotency**: Every booking operation requires an idempotency_key
5. **Testing**: RSpec with factories. Coverage threshold 90%.
6. **Migrations**: Use `disable_ddl_transaction!` with `algorithm: :concurrently` for indexes
7. **Multi-tenancy**: `acts_as_tenant :organization` on all scoped models
8. **Cache**: Pattern-based invalidation via CacheInvalidation concern
9. **AI endpoints**: Under `/api/v1/ai/` namespace
10. **Background jobs**: Sidekiq with weighted queues (critical > default > ai > low)

#[[file:SKILL.md]]
