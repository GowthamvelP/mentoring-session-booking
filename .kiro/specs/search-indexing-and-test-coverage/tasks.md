# Implementation Plan: Search Indexing and Test Coverage

## Overview

Replace the existing BTREE/LIKE-based mentor search with a high-performance trigram (pg_trgm) and GIN index strategy using the pg_search gem. The migration removes the current `index_users_on_lower_name` BTREE index and introduces GIN trigram indexes on `users.name` and `mentor_profiles.expertise`. The MentorsController is refactored to use `pg_search_scope` for cleaner, faster partial/prefix matching. Unit tests validate the new search behavior, existing specs remain green, and load tests confirm performance targets.

## Tasks

- [ ] 1. Add pg_search gem and install dependencies
  - [ ] 1.1 Add pg_search gem to Gemfile and run bundle install
    - Open `backend/Gemfile`
    - Add `gem 'pg_search', '~> 2.3'` in the `# === Application gems ===` section (after existing gems like `pagy`)
    - Run `bundle install` to install the gem and update `Gemfile.lock`
    - Verify gem loads: run `bundle exec rails runner "require 'pg_search'; puts PgSearch::VERSION"` to confirm
    - _Requirements: 4.1, 4.2_

- [ ] 2. Create database migration for trigram indexes
  - [ ] 2.1 Create new migration to enable pg_trgm, replace BTREE with GIN indexes
    - Create file: `backend/db/migrate/20260811120013_add_trigram_search_indexes.rb`
    - Use `disable_ddl_transaction!` (required for concurrent index creation)
    - In `up` method:
      1. `enable_extension 'pg_trgm'` (idempotent — safe if already enabled)
      2. `remove_index :users, name: 'index_users_on_lower_name', if_exists: true`
      3. `add_index :users, :name, name: 'index_users_on_name_trgm', using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently`
      4. `add_index :mentor_profiles, :expertise, name: 'index_mentor_profiles_on_expertise_gin', using: :gin, algorithm: :concurrently`
    - In `down` method:
      1. Remove `index_mentor_profiles_on_expertise_gin` with `if_exists: true`
      2. Remove `index_users_on_name_trgm` with `if_exists: true`
      3. Restore original BTREE: `add_index :users, 'LOWER(name)', name: 'index_users_on_lower_name', algorithm: :concurrently`
    - Run `bin/rails db:migrate` and verify schema.rb updated with new indexes
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3_

- [ ] 3. Add pg_search_scope to User model
  - [ ] 3.1 Configure pg_search_scope in User model
    - Open `backend/app/models/user.rb`
    - Add `include PgSearch::Model` at the top of the class body
    - Add `pg_search_scope :search_by_name, against: :name, using: { trigram: { threshold: 0.3 } }`
    - Verify in console: `bundle exec rails runner "puts User.search_by_name('joh').to_sql"` to confirm scope generates trigram SQL
    - _Requirements: 4.3, 4.4_

- [ ] 4. Refactor MentorsController to use pg_search_scope
  - [ ] 4.1 Replace raw LIKE query with pg_search_scope and expertise array containment
    - Open `backend/app/controllers/api/v1/mentors_controller.rb`
    - Replace the existing search block (`if params[:search].present?` ... `end`) with:
      - Strip the search term: `search_term = params[:search].strip`
      - Get name matches via pg_search: `name_results = mentors.search_by_name(search_term)`
      - Get expertise matches via ILIKE on unnested array: `expertise_results = mentors.joins(:mentor_profile).where("EXISTS (SELECT 1 FROM unnest(mentor_profiles.expertise) AS e WHERE e ILIKE ?)", "%#{search_term}%")`
      - Combine with OR: `mentors = mentors.where(id: name_results.select(:id)).or(mentors.where(id: expertise_results.select(:id)))`
    - Keep `.includes(:mentor_profile)` for eager loading (N+1 prevention)
    - Keep pagination via `pagy(mentors, limit: 20)` and existing response format unchanged
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 5. Checkpoint - Verify basic functionality
  - Ensure migration runs cleanly and server starts without errors.
  - Run `bin/rails db:migrate:status` to confirm migration applied.
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Write RSpec specs for search functionality
  - [ ] 6.1 Create comprehensive search specs
    - Create file: `backend/spec/requests/mentors_search_spec.rb`
    - Set up test data: organization, multiple mentors with distinct names and expertise arrays
    - Write specs for:
      - **Partial name search (3+ chars)**: search "joh" returns mentor "John Smith" via trigram similarity
      - **Prefix search**: search "jan" returns mentor "Jane Doe"
      - **Expertise keyword search**: search "python" returns mentors with "Python" in expertise array
      - **Partial expertise matching**: search "mach" returns mentor with "Machine Learning"
      - **Non-matching term**: search "zzzznonexistent" returns empty `data` array
      - **Case-insensitive name**: search "JOHN" returns same results as "john"
      - **Case-insensitive expertise**: search "RUBY" matches expertise containing "Ruby on Rails"
      - **Blank search param**: `search: ""` returns all mentors
      - **Absent search param**: no `search` key returns all mentors
      - **Response format**: verify `data` (array) and `meta` (with `current_page`, `total_pages`, `total_count`, `per_page`) present
    - Use existing patterns from `spec/requests/mentors_spec.rb` (headers, factories, JSON parsing)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

  - [ ]* 6.2 Write property-based tests for trigram name search
    - **Property 1: Trigram Name Search Returns Matching Mentors**
    - Use `rantly` gem (already in Gemfile) to generate random name substrings of length >= 3
    - For any mentor with name N, any substring S of N where len(S) >= 3 (case-varied), verify search returns that mentor
    - **Validates: Requirements 4.4, 6.1, 6.2, 6.5**

  - [ ]* 6.3 Write property-based tests for expertise search
    - **Property 2: Expertise Keyword Search Returns Matching Mentors**
    - For any mentor with expertise array containing element E, searching with E (case-insensitive) returns that mentor
    - **Validates: Requirements 5.2, 6.3, 6.5**

  - [ ]* 6.4 Write property-based test for response structure invariant
    - **Property 3: Response Structure Invariant**
    - For any request to `GET /api/v1/mentors` (with or without search), verify response has `data` (array) and `meta` (object with pagination keys)
    - **Validates: Requirements 5.4**

  - [ ]* 6.5 Write property-based test for absent search returning all mentors
    - **Property 4: Absent Search Returns All Organization Mentors**
    - For any organization with N mentors, request without `search` param has `meta.total_count == N`
    - **Validates: Requirements 5.3, 6.4**

- [ ] 7. Checkpoint - Run full RSpec suite and verify coverage
  - [ ] 7.1 Run full RSpec suite and validate results
    - Run `bundle exec rspec` from `backend/` directory
    - Verify all 174+ specs pass (zero failures)
    - Check SimpleCov output reports >= 95% line coverage
    - If any existing spec fails, fix the regression without breaking new specs
    - _Requirements: 8.1, 8.2, 9.1, 9.2_

- [ ] 8. Run k6 load tests and verify performance thresholds
  - [ ] 8.1 Execute k6 dev-profile load test suite
    - Ensure the Rails server is running locally (instruct user to start it if needed)
    - Run k6 load tests with dev profile against local server
    - Verify concurrency threshold: exactly 1 booking from 5 concurrent VUs, checks rate > 80%
    - Verify idempotency threshold: at most 1 booking from repeated requests, checks rate > 80%
    - Verify booking flow threshold: p95 response time < 1000ms, failure rate < 30%
    - Verify all 5 test scenarios (concurrency, idempotency, rate limiting, multi-tenant, booking flow) complete without infrastructure errors
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 9. Final checkpoint - All validations pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties using the `rantly` gem already in the project
- Unit tests validate specific examples and edge cases
- The migration uses `disable_ddl_transaction!` which is required for `algorithm: :concurrently` — this is a Rails best practice for production-safe index creation
- The `pg_search` threshold of 0.3 is the pg_trgm default, balancing recall and precision for name searches
- Expertise search uses `ILIKE` on unnested array elements for partial matching support (e.g., "mach" → "Machine Learning")

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["3.1"] },
    { "id": 3, "tasks": ["4.1"] },
    { "id": 4, "tasks": ["6.1"] },
    { "id": 5, "tasks": ["6.2", "6.3", "6.4", "6.5"] },
    { "id": 6, "tasks": ["7.1"] },
    { "id": 7, "tasks": ["8.1"] }
  ]
}
```
