# Requirements Document

## Introduction

This feature replaces the existing BTREE/LIKE-based mentor search with a high-performance trigram (pg_trgm) and GIN index strategy, integrated via the pg_search gem. The migration removes the current `index_users_on_lower_name` BTREE index and introduces GIN trigram indexes on `users.name` and `mentor_profiles.expertise`. The MentorsController is refactored to use `pg_search_scope` for cleaner, faster partial/prefix matching. Unit tests validate trigram search behavior, all existing specs must continue to pass, and load tests confirm non-functional performance targets.

## Glossary

- **Search_System**: The PostgreSQL-backed search subsystem composed of GIN trigram indexes, pg_search gem scopes, and the MentorsController search endpoint.
- **Migration_Runner**: The Rails migration framework responsible for executing database schema changes (adding/removing indexes, enabling extensions).
- **MentorsController**: The Rails API controller at `Api::V1::MentorsController` that handles mentor listing and search requests.
- **User_Model**: The ActiveRecord model representing users, extended with `pg_search_scope` for name-based trigram search.
- **pg_trgm**: The PostgreSQL extension that provides trigram-based similarity matching functions and GIN index operator support.
- **GIN_Index**: A Generalized Inverted Index in PostgreSQL optimized for fast read lookups on text and array columns.
- **Test_Suite**: The RSpec test suite including unit specs, integration specs, and SimpleCov coverage reporting.
- **Load_Test_Suite**: The k6-based load test battery run under the dev profile validating concurrency, idempotency, rate limiting, multi-tenant isolation, and booking flow performance.

## Requirements

### Requirement 1: Enable pg_trgm PostgreSQL Extension

**User Story:** As a developer, I want the pg_trgm extension enabled in PostgreSQL, so that trigram-based GIN indexes and similarity functions are available for search queries.

#### Acceptance Criteria

1. WHEN the migration is executed, THE Migration_Runner SHALL enable the `pg_trgm` extension in the PostgreSQL database.
2. IF the `pg_trgm` extension is already enabled, THEN THE Migration_Runner SHALL complete without error.
3. THE Migration_Runner SHALL execute the extension enablement before any index creation statements in the same migration.

---

### Requirement 2: Replace BTREE Index with GIN Trigram Index on users.name

**User Story:** As a developer, I want the existing BTREE index on `LOWER(name)` replaced with a GIN trigram index, so that partial and prefix name searches execute efficiently using trigram matching.

#### Acceptance Criteria

1. WHEN the migration is executed, THE Migration_Runner SHALL remove the existing `index_users_on_lower_name` BTREE index from the `users` table.
2. WHEN the migration is executed, THE Migration_Runner SHALL create a GIN index using `gin_trgm_ops` on the `users.name` column.
3. THE Migration_Runner SHALL create the GIN index concurrently to avoid table locking in production.
4. IF the migration is rolled back, THEN THE Migration_Runner SHALL remove the GIN trigram index and restore the original BTREE index on `LOWER(name)`.

---

### Requirement 3: Add GIN Index on mentor_profiles.expertise Array Column

**User Story:** As a developer, I want a GIN index on the `mentor_profiles.expertise` array column, so that array containment and overlap queries for expertise filtering execute efficiently.

#### Acceptance Criteria

1. WHEN the migration is executed, THE Migration_Runner SHALL create a GIN index on the `mentor_profiles.expertise` column.
2. THE Migration_Runner SHALL create the expertise GIN index concurrently to avoid table locking.
3. IF the migration is rolled back, THEN THE Migration_Runner SHALL remove the GIN index on `mentor_profiles.expertise`.

---

### Requirement 4: Integrate pg_search Gem

**User Story:** As a developer, I want the pg_search gem added to the project dependencies and configured, so that search scopes use a maintained DSL abstraction instead of raw SQL queries.

#### Acceptance Criteria

1. THE Search_System SHALL declare the `pg_search` gem in the application Gemfile.
2. WHEN the application boots, THE Search_System SHALL load the pg_search library without error.
3. THE User_Model SHALL define a `pg_search_scope` named `:search_by_name` that uses trigram similarity matching against the `name` column.
4. THE User_Model SHALL configure the `:search_by_name` scope to use the `:trigram` search method with a similarity threshold that matches partial input of 3 or more characters (e.g., "joh" matches "John").

---

### Requirement 5: Update MentorsController to Use pg_search_scope

**User Story:** As a developer, I want the MentorsController to use pg_search_scope instead of raw LIKE queries, so that search logic is cleaner and leverages GIN trigram indexes automatically.

#### Acceptance Criteria

1. WHEN a search parameter is provided, THE MentorsController SHALL invoke the `pg_search_scope` on the User_Model instead of constructing raw SQL LIKE clauses.
2. WHEN a search parameter is provided, THE MentorsController SHALL search across both mentor names and expertise areas.
3. WHEN the search parameter is blank or absent, THE MentorsController SHALL return all mentors without applying search filtering.
4. THE MentorsController SHALL maintain the existing response format including `data` and `meta` (pagination) keys.
5. THE MentorsController SHALL maintain the existing eager-loading of `mentor_profile` associations to avoid N+1 queries.

---

### Requirement 6: Search Functionality — Partial and Prefix Matching

**User Story:** As a member, I want to find mentors by typing partial names or expertise keywords, so that I can discover relevant mentors without knowing exact spellings.

#### Acceptance Criteria

1. WHEN a member searches with a partial name of 3 or more characters, THE Search_System SHALL return mentors whose name matches via trigram similarity.
2. WHEN a member searches with a prefix string (e.g., "joh"), THE Search_System SHALL return mentors whose name starts with or contains that prefix (e.g., "John", "Johnson").
3. WHEN a member searches with an expertise keyword, THE Search_System SHALL return mentors whose expertise array contains a matching term.
4. WHEN a member searches with a term that matches no mentors, THE Search_System SHALL return an empty result set with zero records.
5. THE Search_System SHALL perform search matching case-insensitively.

---

### Requirement 7: Unit Test Coverage for Search Functionality

**User Story:** As a developer, I want comprehensive unit tests for the new search functionality, so that trigram matching and expertise search behavior is verified and regressions are caught.

#### Acceptance Criteria

1. THE Test_Suite SHALL include specs verifying that partial name input (3+ characters) returns matching mentors via trigram similarity.
2. THE Test_Suite SHALL include specs verifying that prefix input matches mentor names containing that prefix.
3. THE Test_Suite SHALL include specs verifying that expertise keyword search returns mentors with matching expertise entries.
4. THE Test_Suite SHALL include specs verifying that a non-matching search term returns an empty result set.
5. THE Test_Suite SHALL include specs verifying case-insensitive matching for both name and expertise search.
6. THE Test_Suite SHALL include specs verifying that blank or absent search parameters return all mentors.

---

### Requirement 8: Existing Test Suite Regression Validation

**User Story:** As a developer, I want all existing RSpec specs to continue passing after the search refactoring, so that no regressions are introduced.

#### Acceptance Criteria

1. WHEN the full RSpec suite is executed after migration and code changes, THE Test_Suite SHALL report all 174 or more existing specs as passing.
2. IF any existing spec fails due to search-related changes, THEN THE Test_Suite SHALL identify the failure clearly so that the developer can resolve it.

---

### Requirement 9: Code Coverage Maintenance

**User Story:** As a developer, I want test coverage to remain at or above 95% after adding new code, so that quality standards are upheld.

#### Acceptance Criteria

1. WHEN the full RSpec suite is executed with SimpleCov, THE Test_Suite SHALL report overall line coverage of 95% or greater.
2. THE Test_Suite SHALL include coverage for all new search-related code paths in the User_Model and MentorsController.

---

### Requirement 10: Load Test Validation of Non-Functional Requirements

**User Story:** As a developer, I want the k6 load test suite (dev profile) to pass after the search changes, so that performance and concurrency guarantees are maintained.

#### Acceptance Criteria

1. WHEN the dev-profile load test suite is executed, THE Load_Test_Suite SHALL pass all concurrency thresholds (exactly 1 booking created from 5 concurrent VUs, checks rate > 80%).
2. WHEN the dev-profile load test suite is executed, THE Load_Test_Suite SHALL pass all idempotency thresholds (at most 1 booking created from repeated requests, checks rate > 80%).
3. WHEN the dev-profile load test suite is executed, THE Load_Test_Suite SHALL pass the booking flow threshold (p95 response time < 1000ms, failure rate < 30%).
4. WHEN the dev-profile load test suite is executed, THE Load_Test_Suite SHALL complete all five test scenarios (concurrency, idempotency, rate limiting, multi-tenant, booking flow) without infrastructure errors.
