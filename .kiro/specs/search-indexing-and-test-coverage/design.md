# Design Document: Search Indexing and Test Coverage

## Architecture Overview

The search subsystem follows a layered architecture:

```
┌──────────────────┐       ┌────────────────────┐       ┌──────────────────────────┐
│ MentorsController│──────▶│  User Model         │──────▶│  PostgreSQL              │
│ (API layer)      │       │  (pg_search_scope)  │       │  (pg_trgm + GIN indexes) │
└──────────────────┘       └────────────────────┘       └──────────────────────────┘
        │                          │                              │
   params[:search]          search_by_name scope          GIN trigram index on
   present? → scope         + expertise filter            users.name + GIN on
   blank? → all mentors                                   mentor_profiles.expertise
```

**Request Flow:**
1. Client sends `GET /api/v1/mentors?search=<term>` with org/user headers
2. `MentorsController#index` checks if `params[:search]` is present
3. If present: applies `User.search_by_name(term)` (pg_search trigram scope) combined with expertise array containment query
4. If blank/absent: returns all mentors (existing behavior)
5. Results are paginated via Pagy and serialized via MentorBlueprint

## Components

### 1. Database Migration

A new migration replaces the current `20260811120011_add_search_and_performance_indexes.rb` with a migration that:

```ruby
# frozen_string_literal: true

class AddTrigramSearchIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Step 1: Enable pg_trgm extension (idempotent)
    enable_extension 'pg_trgm'

    # Step 2: Remove old BTREE index on LOWER(name)
    remove_index :users, name: 'index_users_on_lower_name', if_exists: true

    # Step 3: Add GIN trigram index on users.name
    add_index :users, :name,
              name: 'index_users_on_name_trgm',
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently

    # Step 4: Add GIN index on mentor_profiles.expertise (array)
    add_index :mentor_profiles, :expertise,
              name: 'index_mentor_profiles_on_expertise_gin',
              using: :gin,
              algorithm: :concurrently
  end

  def down
    remove_index :mentor_profiles, name: 'index_mentor_profiles_on_expertise_gin', if_exists: true
    remove_index :users, name: 'index_users_on_name_trgm', if_exists: true

    # Restore original BTREE index
    add_index :users, 'LOWER(name)',
              name: 'index_users_on_lower_name',
              algorithm: :concurrently
  end
end
```

**Key decisions:**
- `disable_ddl_transaction!` required for `algorithm: :concurrently`
- Extension enablement is first (indexes depend on `gin_trgm_ops` operator class)
- `if_exists: true` for defensive removal in rollback

### 2. Gemfile Addition

```ruby
# === Application gems ===
gem 'pg_search', '~> 2.3'
```

Added to the main gem group (not dev/test only) since it's used in production query logic.

### 3. User Model Enhancement

```ruby
class User < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :search_by_name,
                  against: :name,
                  using: {
                    trigram: {
                      threshold: 0.3
                    }
                  }

  # ... existing code unchanged ...
end
```

**Design decisions:**
- `threshold: 0.3` — allows partial matches of 3+ characters while filtering irrelevant results. The default pg_trgm threshold is 0.3, providing a good balance between recall and precision for name searches.
- Only the `name` column is indexed via pg_search_scope. Expertise search uses array containment operators (which benefit from the GIN array index) rather than text similarity.

### 4. MentorsController Refactoring

```ruby
# frozen_string_literal: true

module Api
  module V1
    class MentorsController < BaseController
      def index
        mentors = User.mentors.includes(:mentor_profile)

        if params[:search].present?
          search_term = params[:search].strip
          name_results = mentors.search_by_name(search_term)
          expertise_results = mentors.joins(:mentor_profile)
                                     .where("mentor_profiles.expertise @> ARRAY[?]::varchar[]", search_term)
          mentors = mentors.where(id: name_results.select(:id))
                           .or(mentors.where(id: expertise_results.select(:id)))
        end

        pagy, records = pagy(mentors, limit: 20)

        render json: {
          data: MentorBlueprint.render_as_hash(records, view: :default),
          meta: pagy_metadata(pagy)
        }
      end
    end
  end
end
```

**Design decisions:**
- Combines pg_search name results with expertise array containment using `OR` via subqueries
- Expertise matching uses `@>` (array contains) operator, which leverages the GIN array index
- Falls back to case-insensitive containment for expertise since `@>` is exact match on array elements — a secondary `ILIKE` on `array_to_string` may be needed for partial expertise matching
- Eager-loading preserved via `.includes(:mentor_profile)` to prevent N+1
- Response format unchanged: `{ data: [...], meta: {...} }`

### 5. Alternative Expertise Search Strategy

For partial expertise matching (e.g., "mach" matching "Machine Learning"), an alternative approach using trigram on the array-to-string conversion:

```ruby
# In MentorsController, expertise fallback for partial matching:
expertise_results = mentors.joins(:mentor_profile).where(
  "EXISTS (SELECT 1 FROM unnest(mentor_profiles.expertise) AS e WHERE e ILIKE ?)",
  "%#{search_term}%"
)
```

This maintains the existing behavior where partial expertise terms match (e.g., "python" matches expertise array containing "Python"). The GIN index on the array still assists with query planning.

## Data Models

### Schema Changes Summary

| Table | Index Removed | Index Added | Type |
|-------|--------------|-------------|------|
| `users` | `index_users_on_lower_name` (BTREE on `LOWER(name)`) | `index_users_on_name_trgm` (GIN with `gin_trgm_ops` on `name`) | Trigram similarity |
| `mentor_profiles` | — | `index_mentor_profiles_on_expertise_gin` (GIN on `expertise`) | Array containment |

### Existing Indexes Retained

- `index_bookings_on_member_id_and_status` (BTREE)
- `index_bookings_on_member_org_status` (BTREE)
- All other existing indexes remain unchanged

## Interfaces

### API Endpoint (unchanged contract)

```
GET /api/v1/mentors
  Headers: X-User-Id, X-Org-Id
  Params:  search (optional string)

Response 200:
{
  "data": [
    {
      "id": "uuid",
      "name": "string",
      "email": "string",
      "role": "mentor",
      "bio": "string",
      "expertise": ["string"]
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 1,
    "total_count": 5,
    "per_page": 20
  }
}
```

### Internal Interfaces

```ruby
# User model scope — returns ActiveRecord::Relation
User.search_by_name("joh") # => mentors with name matching "joh" via trigram

# Expertise array containment (raw)
MentorProfile.where("expertise @> ARRAY[?]::varchar[]", "Ruby on Rails")
```

## Error Handling

| Scenario | Handling |
|----------|----------|
| pg_trgm extension unavailable | Migration fails with clear PostgreSQL error; developer must install `postgresql-contrib` |
| Empty search term (blank string) | Controller skips search scope, returns all mentors |
| Very short search term (< 3 chars) | pg_search returns results but with low similarity; threshold filters most out |
| Invalid UTF-8 in search param | Rails parameter parsing handles; pg_search receives sanitized string |
| GIN index not yet built (mid-migration) | `algorithm: :concurrently` allows reads during build; queries fall back to seq scan temporarily |

## Testing Strategy

### Unit Tests (RSpec)

New spec file: `spec/requests/mentors_search_spec.rb`

Tests cover:
- Partial name search (3+ chars) returns matching mentors
- Prefix search returns correct results
- Expertise keyword search returns matching mentors
- Non-matching term returns empty array
- Case-insensitive matching (name + expertise)
- Blank/absent search returns all mentors
- Response format preserved (data + meta keys)

### Existing Suite Regression

- All 174+ existing specs must pass after changes
- SimpleCov coverage must remain >= 95%

### Load Tests (k6)

- Run dev-profile load tests validating:
  - Concurrency: exactly 1 booking from 5 VUs
  - Idempotency: at most 1 booking from repeated requests
  - Booking flow: p95 < 1000ms, failure rate < 30%
  - All 5 scenarios complete without infrastructure errors

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Trigram Name Search Returns Matching Mentors

*For any* mentor with name N in the database, and *for any* substring S of N where `len(S) >= 3`, invoking the search endpoint with S (in any case variation) SHALL return a result set that includes that mentor.

**Validates: Requirements 4.4, 6.1, 6.2, 6.5**

### Property 2: Expertise Keyword Search Returns Matching Mentors

*For any* mentor whose `mentor_profiles.expertise` array contains an element E, searching with the term E (case-insensitive) SHALL return a result set that includes that mentor.

**Validates: Requirements 5.2, 6.3, 6.5**

### Property 3: Response Structure Invariant

*For any* authenticated request to `GET /api/v1/mentors` (with or without a search parameter), the response body SHALL contain a `data` key with an array value and a `meta` key with an object containing `current_page`, `total_pages`, `total_count`, and `per_page` fields.

**Validates: Requirements 5.4**

### Property 4: Absent Search Returns All Organization Mentors

*For any* organization with N mentors, a request to `GET /api/v1/mentors` without a `search` parameter (or with a blank `search` parameter) SHALL return exactly N mentors in the `data` array (accounting for pagination boundaries — specifically, `meta.total_count` SHALL equal N).

**Validates: Requirements 5.3, 6.4**
