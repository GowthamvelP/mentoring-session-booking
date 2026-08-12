# PHASE 2 PROMPT — AI-AUGMENTED MENTORING PLATFORM
## MentorBook Tech Lead Take-Home | Post-MVP AI Features
## Candidate: Gowthamvel Palanivel
## Date: 2026-08-11
## Estimated Effort: 3–5 days (post 48-hour MVP)

---

# CONTEXT

You have completed the 48-hour MVP of the MentorBook Mentoring Session Booking system:
- Rails 8 API-only backend with PostgreSQL, Redis, Sidekiq
- Optimistic locking on slots, idempotency on bookings, multi-tenancy via `Current.org_id`
- React 18 + Vite + TanStack Query frontend
- Docker-compose orchestration

This Phase 2 prompt extends that foundation with **AI-native capabilities** that demonstrate platform thinking beyond CRUD. The goal is to show MentorBook that you understand how to integrate LLMs into production systems safely, observably, and with proper async architecture.

**Constraint:** Build on the existing Rails MVP. No infrastructure changes beyond adding `pgvector` to PostgreSQL and an OpenAI/Anthropic API key.

---

# PRIORITY FRAMEWORK

| Priority | Feature | Effort | MentorBook Signal |
|----------|---------|--------|----------------|
| **P1** | Agent Skill (`SKILL.md`) + AI Context API | 2 hours | AI-native SDLC |
| **P1** | Pre-Session Brief Generation | 4 hours | LLM orchestration in async jobs |
| **P2** | Mentor-Member Semantic Matching | 6 hours | Vector search + embeddings |
| **P2** | MCP Server Scaffold | 4 hours | AI agent interoperability |
| **P3** | Natural Language Booking (Documented Only) | 1 hour | Function calling architecture |
| **P3** | Codebase RAG Pipeline (Documented Only) | 1 hour | Self-onboarding vision |

**Rule:** Do not start P2 until P1 is complete and tested. Do not start P3 until P2 is stable.

---

# P1 — AGENT SKILL & AI CONTEXT API

## 1.1 SKILL.md (Repository Root)

Create `/SKILL.md` at repository root. This file encodes architecture conventions so AI coding assistants (Kiro, Cursor, Claude Code, Copilot Workspace) produce codebase-consistent output.

### Required Sections

```markdown
# MentorBook Booking System — Agent Skill

## System Overview
Rails 8 API-only backend for a multi-tenant mentoring session booking platform.
React 18 + Vite SPA frontend. Sidekiq + Redis for async jobs. PostgreSQL with pgvector.

## Architecture Rules
1. **Controllers are thin.** They validate params, call Services, render Serializers.
2. **All business logic lives in `app/services/`.** Never put business logic in models beyond validations/associations.
3. **Optimistic locking is mandatory for slot mutations.** Always respect `lock_version`.
4. **Idempotency is mandatory for bookings.** Always check `idempotency_key` before creation.
5. **Multi-tenancy is enforced at the query layer.** Use `Current.org_id`. Never bypass scoping.
6. **Cache invalidation is pattern-based.** On slot mutation: `Rails.cache.delete_matched("slots:#{mentor_id}:*")`.
7. **Sidekiq jobs inherit from `ApplicationJob`.** Set `sidekiq_options retry: 3` unless specified otherwise.

## File Organization
- `app/controllers/api/v1/` — Versioned API controllers
- `app/services/` — Business logic (BookingService, SlotService, etc.)
- `app/serializers/` — Blueprinter serializers
- `app/jobs/` — Sidekiq jobs
- `app/models/concerns/` — Shared model behavior (Tenantable, Idempotent)
- `db/migrate/` — Strong Migrations validated

## Common Tasks

### Adding a New Endpoint
1. Controller action in `Api::V1::*Controller`
2. Service class in `app/services/`
3. Serializer in `app/serializers/`
4. Route in `config/routes.rb`
5. Request spec in `spec/requests/`

### Modifying Slot Status
- Never update `slots` directly from controllers.
- Always go through `SlotService` or `BookingService`.
- Respect `lock_version`. Handle `ActiveRecord::StaleObjectError` with retry.

### Adding a Background Job
```ruby
class MyJob < ApplicationJob
  sidekiq_options retry: 3, queue: 'default'
  def perform(record_id)
    # idempotent implementation
  end
end
```

### Database Conventions
- UUID primary keys via `pgcrypto`
- Indexed foreign keys: `[org_id]`, `[mentor_id]`, `[member_id]`
- Composite unique indexes where applicable: `[mentor_id, start_time]`
- Enum fields use Rails `enum` with integer backing

## Testing
- Run backend: `docker-compose exec backend bundle exec rspec`
- Run specific concurrency tests: `rspec spec/services/booking_service_spec.rb`
- Seed data creates: 3 orgs, 5 mentors, 20 slots, 2 demo bookings

## AI Features (Phase 2)
- Pre-session briefs generated via LLM in `BookingBriefJob`
- Mentor matching via pgvector embeddings
- MCP server exposes tools at `/api/v1/ai/mcp`
```

## 1.2 AI Context Controller

Expose machine-readable system context so AI agents can discover capabilities without reading source code.

### Endpoint
```
GET /api/v1/ai/context
```

### Response Schema
```json
{
  "system": {
    "name": "MentorBook Mentoring Booking",
    "version": "1.0.0",
    "stack": ["Rails 8 API-only", "PostgreSQL 16", "Redis 7", "Sidekiq", "React 18 + Vite"]
  },
  "schema": {
    "organizations": {
      "fields": ["id", "name", "timezone"],
      "tenancy": "root_scope"
    },
    "users": {
      "fields": ["id", "org_id", "email", "name", "role"],
      "roles": ["member", "mentor", "admin"],
      "tenancy": "org_id"
    },
    "slots": {
      "fields": ["id", "mentor_id", "start_time", "end_time", "status", "lock_version"],
      "statuses": ["available", "booked"],
      "locking": "optimistic (lock_version)",
      "tenancy": "via mentor -> user -> org_id"
    },
    "bookings": {
      "fields": ["id", "slot_id", "member_id", "status", "idempotency_key", "booked_at"],
      "statuses": ["confirmed", "cancelled", "completed"],
      "idempotency": "UNIQUE(idempotency_key)",
      "tenancy": "via member -> user -> org_id"
    }
  },
  "conventions": {
    "write_path": "Controller -> Service -> Model",
    "caching": "Cache-aside with Redis, pattern-based invalidation",
    "async": "Sidekiq jobs for notifications, briefs, cache invalidation",
    "locking": "Optimistic locking on slots; idempotency on bookings"
  },
  "endpoints": [
    { "method": "GET", "path": "/api/v1/mentors", "auth": "org-scoped", "description": "List mentors" },
    { "method": "GET", "path": "/api/v1/mentors/:id/slots", "auth": "org-scoped", "description": "Available slots for mentor" },
    { "method": "POST", "path": "/api/v1/bookings", "auth": "org-scoped + idempotency", "description": "Book a slot" },
    { "method": "PATCH", "path": "/api/v1/bookings/:id/cancel", "auth": "org-scoped", "description": "Cancel booking" }
  ],
  "ai_features": {
    "pre_session_briefs": true,
    "mentor_matching": false,
    "natural_language_booking": false,
    "mcp_server": false
  }
}
```

### Implementation
```ruby
# app/controllers/api/v1/ai/context_controller.rb
module Api::V1::Ai
  class ContextController < ApplicationController
    skip_before_action :authenticate_user!, only: [:show] # Or your auth stub

    def show
      render json: {
        system: system_meta,
        schema: schema_definition,
        conventions: conventions,
        endpoints: api_endpoints,
        ai_features: ai_feature_flags
      }
    end

    private

    def system_meta
      {
        name: "MentorBook Mentoring Booking",
        version: "1.0.0",
        stack: ["Rails 8 API-only", "PostgreSQL 16", "Redis 7", "Sidekiq", "React 18 + Vite"]
      }
    end

    def schema_definition
      {
        organizations: { fields: %w[id name timezone], tenancy: "root_scope" },
        users: { fields: %w[id org_id email name role], roles: %w[member mentor admin], tenancy: "org_id" },
        slots: {
          fields: %w[id mentor_id start_time end_time status lock_version],
          statuses: %w[available booked],
          locking: "optimistic (lock_version)",
          tenancy: "via mentor -> user -> org_id"
        },
        bookings: {
          fields: %w[id slot_id member_id status idempotency_key booked_at],
          statuses: %w[confirmed cancelled completed],
          idempotency: "UNIQUE(idempotency_key)",
          tenancy: "via member -> user -> org_id"
        }
      }
    end

    def conventions
      {
        write_path: "Controller -> Service -> Model",
        caching: "Cache-aside with Redis, pattern-based invalidation",
        async: "Sidekiq jobs for notifications, briefs, cache invalidation",
        locking: "Optimistic locking on slots; idempotency on bookings"
      }
    end

    def api_endpoints
      [
        { method: "GET", path: "/api/v1/mentors", auth: "org-scoped", description: "List mentors" },
        { method: "GET", path: "/api/v1/mentors/:id/slots", auth: "org-scoped", description: "Available slots for mentor" },
        { method: "POST", path: "/api/v1/bookings", auth: "org-scoped + idempotency", description: "Book a slot" },
        { method: "PATCH", path: "/api/v1/bookings/:id/cancel", auth: "org-scoped", description: "Cancel booking" },
        { method: "GET", path: "/api/v1/me/sessions", auth: "org-scoped", description: "My bookings as member" },
        { method: "GET", path: "/api/v1/me/mentor-sessions", auth: "org-scoped", description: "My bookings as mentor" }
      ]
    end

    def ai_feature_flags
      {
        pre_session_briefs: true,
        mentor_matching: false,
        natural_language_booking: false,
        mcp_server: false
      }
    end
  end
end
```

### Routes
```ruby
namespace :ai do
  get 'context', to: 'context#show'
end
```

---

# P1 — PRE-SESSION BRIEF GENERATION

## Overview
When a member books a session, an LLM generates a **personalized pre-session brief** for the mentor: suggested discussion topics, member context, and preparation notes. Delivered asynchronously via email/Sidekiq.

## Why This Feature
- Demonstrates **LLM orchestration in production async jobs** (exactly what you do at Nextpoint)
- Adds real user value without UI complexity
- Shows observability: LLM latency, token usage, failure handling
- Off request path: API stays <100ms

## Data Model Changes

### Migration
```ruby
class CreatePreSessionBriefs < ActiveRecord::Migration[8.0]
  def change
    create_table :pre_session_briefs, id: :uuid do |t|
      t.references :booking, type: :uuid, null: false, foreign_key: true
      t.text :content, null: false
      t.string :model_used, null: false # e.g., "gpt-4o"
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens
      t.string :status, null: false, default: "pending" # pending, generated, failed
      t.text :error_message
      t.timestamps
    end

    add_index :pre_session_briefs, :booking_id, unique: true
  end
end
```

### Model
```ruby
class PreSessionBrief < ApplicationRecord
  belongs_to :booking
  enum status: { pending: 0, generated: 1, failed: 2 }

  validates :content, presence: true, if: :generated?
  validates :model_used, presence: true, if: :generated?
end
```

## Service: LlmClient

Create a reusable LLM client service. Use `faraday` for HTTP, `dotenv-rails` for API keys.

```ruby
# app/services/llm_client.rb
class LlmClient
  TIMEOUT = 30
  DEFAULT_MODEL = "gpt-4o-mini" # Cost-effective for MVP

  def self.generate_brief(member:, mentor:, booking_notes:)
    new.generate_brief(member:, mentor:, booking_notes:)
  end

  def initialize(api_key: ENV.fetch('OPENAI_API_KEY'))
    @api_key = api_key
    @client = Faraday.new(url: 'https://api.openai.com') do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
      f.options.timeout = TIMEOUT
    end
  end

  def generate_brief(member:, mentor:, booking_notes:)
    response = @client.post('/v1/chat/completions', {
      model: DEFAULT_MODEL,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt(member, mentor, booking_notes) }
      ],
      temperature: 0.7,
      max_tokens: 500
    }.to_json, headers)

    handle_response(response)
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    { success: false, error: "LLM timeout: #{e.message}" }
  end

  private

  def headers
    { 'Authorization' => "Bearer #{@api_key}", 'Content-Type' => 'application/json' }
  end

  def system_prompt
    <<~PROMPT
      You are an expert mentoring coach. Generate a concise pre-session brief 
      for a mentor. Include: 1) Member context, 2) 3 suggested discussion topics, 
      3) 1 preparation tip. Be specific, actionable, and professional. 
      Max 300 words.
    PROMPT
  end

  def user_prompt(member, mentor, notes)
    <<~PROMPT
      Mentor: #{mentor.name} | Expertise: #{mentor.mentor_profile.expertise.join(', ')}
      Member: #{member.name} | Role: #{member.role}
      Booking Notes: #{notes || 'None provided'}

      Generate a pre-session brief.
    PROMPT
  end

  def handle_response(response)
    if response.success?
      body = response.body
      choice = body.dig('choices', 0, 'message', 'content')
      usage = body['usage'] || {}

      {
        success: true,
        content: choice,
        model: body['model'],
        prompt_tokens: usage['prompt_tokens'],
        completion_tokens: usage['completion_tokens'],
        total_tokens: usage['total_tokens']
      }
    else
      { success: false, error: "LLM API error: #{response.body.dig('error', 'message')}" }
    end
  end
end
```

## Job: BookingBriefJob

```ruby
# app/jobs/booking_brief_job.rb
class BookingBriefJob < ApplicationJob
  sidekiq_options retry: 3, queue: 'ai'

  def perform(booking_id)
    booking = Booking.includes(slot: { mentor: :mentor_profile }, member: {}).find(booking_id)
    return unless booking.confirmed?

    # Idempotency: skip if brief already exists
    return if PreSessionBrief.exists?(booking_id: booking_id)

    result = LlmClient.generate_brief(
      member: booking.member,
      mentor: booking.slot.mentor,
      booking_notes: booking.notes
    )

    if result[:success]
      PreSessionBrief.create!(
        booking: booking,
        content: result[:content],
        model_used: result[:model],
        prompt_tokens: result[:prompt_tokens],
        completion_tokens: result[:completion_tokens],
        total_tokens: result[:total_tokens],
        status: :generated
      )

      # Optionally enqueue email delivery here
      # BriefDeliveryJob.perform_later(booking_id)

      Rails.logger.info("[AI] Brief generated for booking #{booking_id}, tokens: #{result[:total_tokens]}")
    else
      PreSessionBrief.create!(
        booking: booking,
        status: :failed,
        error_message: result[:error]
      )

      Rails.logger.error("[AI] Brief failed for booking #{booking_id}: #{result[:error]}")
      raise StandardError, result[:error] # Trigger Sidekiq retry
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("[AI] Booking #{booking_id} not found, skipping brief generation")
  end
end
```

### Sidekiq Queue Config
```yaml
# config/sidekiq.yml
:concurrency: 5
:queues:
  - [critical, 2]
  - [default, 1]
  - [ai, 1] # Separate queue for LLM jobs to isolate latency
```

## Integration with BookingService

Update `BookingService` to enqueue the job:

```ruby
# In app/services/booking_service.rb, after successful booking creation:
BookingBriefJob.perform_later(booking.id)
```

## API Endpoint for Brief Retrieval

```ruby
# GET /api/v1/bookings/:id/brief
class Api::V1::Bookings::BriefsController < ApplicationController
  def show
    booking = Booking.includes(:pre_session_brief).find(params[:booking_id])
    brief = booking.pre_session_brief

    if brief&.generated?
      render json: {
        status: brief.status,
        content: brief.content,
        model: brief.model_used,
        tokens: brief.total_tokens,
        generated_at: brief.updated_at
      }
    elsif brief&.pending?
      render json: { status: "pending", message: "Brief is being generated" }, status: :accepted
    else
      render json: { status: "not_found", message: "No brief available" }, status: :not_found
    end
  end
end
```

## Observability Requirements

Log these fields for every LLM call:
- `event`: "llm.brief_generation"
- `booking_id`
- `model`
- `prompt_tokens`, `completion_tokens`, `total_tokens`
- `duration_ms`
- `success` (boolean)
- `error` (if failed)

Add to `lograge` custom payload:
```ruby
# config/initializers/lograge.rb
config.lograge.custom_payload do |controller|
  if controller.is_a?(Api::V1::Ai::BriefsController)
    { ai_model: controller.params[:model], ai_tokens: controller.params[:total_tokens] }
  end
end
```

---

# P2 — MENTOR-MEMBER SEMANTIC MATCHING

## Overview
Allow members to discover mentors based on **semantic similarity** between their goals/interests and mentor expertise. Uses pgvector + OpenAI embeddings.

## Why This Feature
- Demonstrates **vector search architecture** (you built this at Nextpoint with Voyage + HNSW)
- Shows you understand embeddings, cosine similarity, and hybrid retrieval
- Differentiator: most candidates stop at CRUD; you build intelligent matching

## Infrastructure Changes

### Enable pgvector
```ruby
# Migration (run before embedding migration)
class EnablePgvector < ActiveRecord::Migration[8.0]
  def up
    execute 'CREATE EXTENSION IF NOT EXISTS vector'
  end

  def down
    execute 'DROP EXTENSION IF EXISTS vector'
  end
end
```

### Update MentorProfile
```ruby
class AddEmbeddingToMentorProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :mentor_profiles, :expertise_embedding, :vector, limit: 1536
    add_index :mentor_profiles, :expertise_embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end
```

**Note:** Use `ivfflat` for MVP (faster build, good enough for <10k mentors). Document `hnsw` as production upgrade path.

### Model Update
```ruby
# app/models/mentor_profile.rb
class MentorProfile < ApplicationRecord
  belongs_to :user
  has_neighbors :expertise_embedding, dimensions: 1536

  validates :bio, presence: true

  # Trigger embedding generation on create/update
  after_save :generate_embedding, if: :saved_change_to_expertise?

  private

  def generate_embedding
    MentorEmbeddingJob.perform_later(id)
  end
end
```

## Service: EmbeddingGenerator

```ruby
# app/services/embedding_generator.rb
class EmbeddingGenerator
  DEFAULT_MODEL = "text-embedding-3-small"
  DIMENSIONS = 1536

  def self.generate_for_mentor(mentor_profile)
    new.generate_for_mentor(mentor_profile)
  end

  def self.generate_for_query(text)
    new.generate_for_query(text)
  end

  def initialize(api_key: ENV.fetch('OPENAI_API_KEY'))
    @api_key = api_key
    @client = Faraday.new(url: 'https://api.openai.com') do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
      f.options.timeout = 30
    end
  end

  def generate_for_mentor(mentor_profile)
    text = "#{mentor_profile.bio} Expertise: #{mentor_profile.expertise.join(', ')}"
    embedding = fetch_embedding(text)
    mentor_profile.update!(expertise_embedding: embedding)
  end

  def generate_for_query(text)
    fetch_embedding(text)
  end

  private

  def fetch_embedding(text)
    response = @client.post('/v1/embeddings', {
      input: text,
      model: DEFAULT_MODEL,
      dimensions: DIMENSIONS
    }.to_json, headers)

    raise "Embedding API error: #{response.body}" unless response.success?

    response.body.dig('data', 0, 'embedding')
  end

  def headers
    { 'Authorization' => "Bearer #{@api_key}", 'Content-Type' => 'application/json' }
  end
end
```

## Job: MentorEmbeddingJob

```ruby
# app/jobs/mentor_embedding_job.rb
class MentorEmbeddingJob < ApplicationJob
  sidekiq_options retry: 3, queue: 'ai'

  def perform(mentor_profile_id)
    profile = MentorProfile.find(mentor_profile_id)
    EmbeddingGenerator.generate_for_mentor(profile)
    Rails.logger.info("[AI] Embedding generated for mentor #{profile.user_id}")
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("[AI] MentorProfile #{mentor_profile_id} not found")
  end
end
```

## API: Semantic Mentor Search

```ruby
# GET /api/v1/mentors/search?q=machine+learning+for+legal+tech
class Api::V1::Mentors::SearchController < ApplicationController
  def index
    query = params[:q].to_s.strip
    return render json: { error: "Query required" }, status: :bad_request if query.blank?

    query_embedding = EmbeddingGenerator.generate_for_query(query)

    mentors = MentorProfile
      .nearest_neighbors(:expertise_embedding, query_embedding, distance: "cosine")
      .includes(user: :organization)
      .where(users: { org_id: Current.org_id }) # Tenant scoping
      .first(10)

    render json: {
      query: query,
      results: mentors.map do |profile|
        {
          mentor_id: profile.user_id,
          name: profile.user.name,
          bio: profile.bio,
          expertise: profile.expertise,
          similarity_score: 1 - profile.neighbor_distance # Convert cosine distance to similarity
        }
      end
    }
  rescue StandardError => e
    Rails.logger.error("[AI] Mentor search failed: #{e.message}")
    render json: { error: "Search failed" }, status: :internal_server_error
  end
end
```

### Seed Script Update
Ensure all demo mentors get embeddings on seed:
```ruby
# In db/seeds.rb, after creating mentor_profiles:
MentorProfile.find_each do |profile|
  MentorEmbeddingJob.perform_later(profile.id)
end
```

## Hybrid Search (Documented, Not Required)

In README, document how you would combine semantic + keyword search:
> "Current implementation uses pure semantic search. Production would use hybrid retrieval: BM25 keyword search on bio + pgvector cosine similarity, fused via Reciprocal Rank Fusion (RRF) with weights 0.7 semantic / 0.3 keyword. This is the exact pattern I built at Nextpoint for e-discovery search."

---

# P2 — MCP SERVER SCAFFOLD

## Overview
Implement a Model Context Protocol (MCP) server interface that exposes booking system capabilities as **tools** to AI agents (Claude Code, Cursor, Kiro). This allows natural-language operations: *"Book a session with Sarah for tomorrow at 2pm"* → AI calls your API via MCP.

## Why This Feature
- MentorBook is AI-native; MCP is the emerging standard for AI-agent interoperability
- Shows you understand **AI-agent architecture**, not just LLM API calls
- Differentiator: very few candidates build MCP servers

## MCP Specification

MCP uses JSON-RPC 2.0 over stdio or HTTP. For a Rails API, implement the HTTP transport layer.

### Tools Definition

```ruby
# app/controllers/api/v1/ai/mcp_controller.rb
module Api::V1::Ai
  class McpController < ApplicationController
    skip_before_action :authenticate_user! # Or use API key auth

    def tools
      render json: {
        tools: [
          {
            name: "list_mentors",
            description: "List all available mentors in the current organization",
            input_schema: {
              type: "object",
              properties: {}
            }
          },
          {
            name: "list_slots",
            description: "List available slots for a specific mentor",
            input_schema: {
              type: "object",
              properties: {
                mentor_id: { type: "string", description: "UUID of the mentor" },
                date: { type: "string", description: "ISO 8601 date (optional, defaults to today)" }
              },
              required: ["mentor_id"]
            }
          },
          {
            name: "book_slot",
            description: "Book a mentoring slot for a member",
            input_schema: {
              type: "object",
              properties: {
                slot_id: { type: "string", description: "UUID of the slot to book" },
                member_id: { type: "string", description: "UUID of the member" },
                notes: { type: "string", description: "Optional notes for the session" }
              },
              required: ["slot_id", "member_id"]
            }
          },
          {
            name: "cancel_booking",
            description: "Cancel an existing booking",
            input_schema: {
              type: "object",
              properties: {
                booking_id: { type: "string", description: "UUID of the booking to cancel" }
              },
              required: ["booking_id"]
            }
          },
          {
            name: "my_sessions",
            description: "Get my upcoming and past sessions",
            input_schema: {
              type: "object",
              properties: {
                role: { type: "string", enum: ["member", "mentor"], description: "Filter by role perspective" }
              }
            }
          }
        ]
      }
    end

    def call
      tool_name = params[:name]
      arguments = params[:arguments] || {}

      result = case tool_name
               when "list_mentors" then handle_list_mentors
               when "list_slots" then handle_list_slots(arguments)
               when "book_slot" then handle_book_slot(arguments)
               when "cancel_booking" then handle_cancel_booking(arguments)
               when "my_sessions" then handle_my_sessions(arguments)
               else { error: "Unknown tool: #{tool_name}" }
               end

      render json: result
    end

    private

    def handle_list_mentors
      mentors = User.where(org_id: Current.org_id, role: :mentor).includes(:mentor_profile)
      { mentors: mentors.map { |m| { id: m.id, name: m.name, expertise: m.mentor_profile&.expertise } } }
    end

    def handle_list_slots(args)
      mentor = User.find_by(id: args["mentor_id"], org_id: Current.org_id)
      return { error: "Mentor not found" } unless mentor

      date = args["date"] ? Date.parse(args["date"]) : Date.today
      slots = mentor.slots.available.where("DATE(start_time) = ?", date)

      { slots: slots.map { |s| { id: s.id, start: s.start_time.iso8601, end: s.end_time.iso8601 } } }
    rescue ArgumentError
      { error: "Invalid date format" }
    end

    def handle_book_slot(args)
      service = BookingService.new(
        slot_id: args["slot_id"],
        member_id: args["member_id"],
        idempotency_key: "mcp_#{args['slot_id']}_#{args['member_id']}_#{Time.now.to_i}",
        notes: args["notes"]
      )

      result = service.call
      if result.success?
        { booking_id: result.booking.id, status: "confirmed", message: "Session booked successfully" }
      else
        { error: result.error, status: "failed" }
      end
    end

    def handle_cancel_booking(args)
      booking = Booking.find_by(id: args["booking_id"])
      return { error: "Booking not found" } unless booking

      service = CancellationService.new(booking: booking)
      result = service.call

      if result.success?
        { status: "cancelled", message: "Booking cancelled successfully" }
      else
        { error: result.error }
      end
    end

    def handle_my_sessions(args)
      role = args["role"] || "member"
      bookings = case role
                 when "member" then Booking.where(member_id: Current.user_id).includes(:slot)
                 when "mentor" then Booking.joins(:slot).where(slots: { mentor_id: Current.user_id })
                 else Booking.none
                 end

      { sessions: bookings.map { |b| { id: b.id, status: b.status, time: b.slot.start_time.iso8601 } } }
    end
  end
end
```

### Routes
```ruby
namespace :ai do
  get 'mcp/tools', to: 'mcp#tools'
  post 'mcp/call', to: 'mcp#call'
end
```

### MCP Client Configuration (for README)

Document how to connect Claude Code or Cursor:

```json
{
  "mcpServers": {
    "mentorbook-system": {
      "url": "http://localhost:3000/api/v1/ai/mcp",
      "headers": {
        "Authorization": "Bearer stub-token",
        "X-Org-Id": "your-org-uuid"
      }
    }
  }
}
```

---

# P3 — DOCUMENTED FUTURE FEATURES (Architecture Only)

## Natural Language Booking

Document in README the architecture for conversational booking:

```markdown
### Natural Language Booking (Future)
A dedicated NLU service would parse member intent:
- "Book me 30 minutes with Sarah next Tuesday afternoon"
- → Intent: book_slot
- → Entities: { mentor_name: "Sarah", duration: "30m", date: "next Tuesday", time: "afternoon" }
- → Resolution: Query mentor by name → find available slots → match duration → present options

Implementation: OpenAI Function Calling with 4 defined functions (list_mentors, list_slots, book_slot, confirm). 
State managed via conversation_id in Redis (TTL 10 minutes).
```

## Codebase RAG Pipeline (Future)

Document the architecture for self-onboarding:

```markdown
### Codebase RAG Self-Onboarding (Future)
Enable new engineers to ask the codebase questions via natural language.

Pipeline:
1. **Chunking:** Tree-sitter parses Ruby files into method/class chunks
2. **Embedding:** `text-embedding-3-small` generates 1536-dim vectors
3. **Storage:** `pgvector` in existing PostgreSQL (table: `code_chunks`)
4. **Retrieval:** Cosine similarity search on query embedding
5. **Synthesis:** GPT-4o answers using retrieved chunks as context

Table schema:
- `code_chunks`: id, file_path, content, embedding (vector 1536), chunk_type (method/class/module)
- Index: ivfflat on embedding with cosine ops

API: `POST /api/v1/ai/ask { "question": "How does locking work?" }`
```

---

# ENVIRONMENT CONFIGURATION

Add to `.env` and `docker-compose.yml`:

```bash
# .env
OPENAI_API_KEY=sk-...
OPENAI_ORG_ID=optional
EMBEDDING_MODEL=text-embedding-3-small
LLM_MODEL=gpt-4o-mini
ENABLE_AI_FEATURES=true
```

```yaml
# docker-compose.yml (backend service env)
environment:
  OPENAI_API_KEY: ${OPENAI_API_KEY}
  ENABLE_AI_FEATURES: ${ENABLE_AI_FEATURES:-true}
```

**Guard clause:** All AI features check `ENV['ENABLE_AI_FEATURES'] == 'true'` and gracefully degrade if the key is missing.

---

# TESTING REQUIREMENTS

## Pre-Session Brief Job
```ruby
# spec/jobs/booking_brief_job_spec.rb
RSpec.describe BookingBriefJob do
  let(:booking) { create(:booking, :confirmed) }

  it "generates a brief successfully" do
    allow(LlmClient).to receive(:generate_brief).and_return(
      success: true, content: "Test brief", model: "gpt-4o-mini", total_tokens: 150
    )

    expect { described_class.perform_async(booking.id) }.to change(PreSessionBrief, :count).by(1)

    brief = PreSessionBrief.last
    expect(brief.content).to eq("Test brief")
    expect(brief.generated?).to be true
  end

  it "is idempotent" do
    create(:pre_session_brief, booking: booking, status: :generated)
    allow(LlmClient).to receive(:generate_brief)

    described_class.perform_async(booking.id)
    expect(LlmClient).not_to have_received(:generate_brief)
  end

  it "retries on LLM failure" do
    allow(LlmClient).to receive(:generate_brief).and_return(success: false, error: "Timeout")

    expect { described_class.perform_async(booking.id) }.to raise_error
    # Sidekiq retry handles this
  end
end
```

## Mentor Embedding
```ruby
# spec/services/embedding_generator_spec.rb
RSpec.describe EmbeddingGenerator do
  let(:profile) { create(:mentor_profile, expertise: ["Ruby", "Rails"]) }

  it "generates a 1536-dim embedding" do
    VCR.use_cassette('openai_embedding') do
      EmbeddingGenerator.generate_for_mentor(profile)
      expect(profile.reload.expertise_embedding).to be_present
      expect(profile.expertise_embedding.size).to eq(1536)
    end
  end
end
```

## MCP Controller
```ruby
# spec/requests/mcp_spec.rb
RSpec.describe "MCP Server" do
  describe "GET /api/v1/ai/mcp/tools" do
    it "returns tool definitions" do
      get '/api/v1/ai/mcp/tools'
      expect(response).to have_http_status(:ok)
      expect(json['tools']).to be_an(Array)
      expect(json['tools'].map { |t| t['name'] }).to include('list_mentors', 'book_slot')
    end
  end

  describe "POST /api/v1/ai/mcp/call" do
    it "books a slot via tool call" do
      slot = create(:slot, :available)
      member = create(:user, :member)

      post '/api/v1/ai/mcp/call', params: {
        name: "book_slot",
        arguments: { slot_id: slot.id, member_id: member.id }
      }

      expect(response).to have_http_status(:ok)
      expect(json['status']).to eq('confirmed')
    end
  end
end
```

---

# README ADDITIONS

Add an **"AI-Native Architecture"** section:

```markdown
## AI-Native Architecture

This system is designed to be operated by AI agents, not just used by humans.

### Agent Skill (`SKILL.md`)
The repository root includes `SKILL.md`, encoding architecture conventions for 
AI coding assistants (Kiro, Cursor, Claude Code). This enables codebase-consistent 
AI-generated output without human context transfer.

### AI Context API
`GET /api/v1/ai/context` exposes machine-readable system metadata: schema, 
conventions, endpoints, and feature flags. AI agents discover capabilities 
programmatically.

### Pre-Session Briefs (Implemented)
When a booking is confirmed, `BookingBriefJob` calls OpenAI to generate a 
personalized mentor brief (discussion topics, preparation tips). Delivered 
asynchronously via Sidekiq. Token usage and latency are logged for observability.

### Mentor Matching (Implemented)
Mentor expertise is embedded via OpenAI `text-embedding-3-small` and stored 
in PostgreSQL using `pgvector`. Members search with natural language; results 
ranked by cosine similarity. Hybrid retrieval (BM25 + vector) documented as 
production evolution.

### MCP Server (Implemented)
`GET /api/v1/ai/mcp/tools` and `POST /api/v1/ai/mcp/call` implement the 
Model Context Protocol. AI agents (Claude Code, Cursor) can list mentors, 
find slots, and book sessions via tool-calling.

### Future: Natural Language Booking
Documented architecture for conversational booking via OpenAI Function Calling 
with Redis-backed conversation state.

### Future: Codebase RAG Self-Onboarding
Documented architecture for semantic code search using Tree-sitter chunking, 
pgvector storage, and GPT-4o synthesis. Enables new engineers to query the 
codebase via natural language.
```

---

# AI USAGE LOG (For MentorBook)

Document how AI was used in Phase 2:

```markdown
## AI Usage Log (Phase 2)

| Feature | AI Role | Human Override |
|---------|---------|----------------|
| SKILL.md structure | AI suggested sections; human refined conventions | Added specific Rails patterns (Service objects, cache invalidation) |
| LlmClient service | AI generated Faraday client scaffold | Added timeout handling, token tracking, idempotency checks |
| MCP tool definitions | AI generated JSON schemas | Human validated against actual API controllers, added error handling |
| Embedding pipeline | AI suggested pgvector + neighbor gem | Human chose ivfflat over hnsw for MVP simplicity |
| Test stubs | AI generated RSpec structure | Human added VCR cassette guidance and retry assertions |
```

---

# SUCCESS CRITERIA

Phase 2 is complete when:
- [ ] `SKILL.md` exists at repo root and follows the spec above
- [ ] `GET /api/v1/ai/context` returns valid system metadata
- [ ] Booking a slot triggers `BookingBriefJob` and creates a `PreSessionBrief` record
- [ ] Mentor profiles have `expertise_embedding` populated via seed
- [ ] `GET /api/v1/mentors/search?q=...` returns ranked results with similarity scores
- [ ] `GET /api/v1/ai/mcp/tools` returns valid MCP tool definitions
- [ ] `POST /api/v1/ai/mcp/call` successfully executes booking tools
- [ ] All AI features gracefully degrade when `OPENAI_API_KEY` is missing
- [ ] README documents all AI features + future architecture
- [ ] All new code has request specs or service specs
- [ ] `docker-compose up` still works end-to-end

---

# KIRO INSTRUCTIONS

1. Implement in priority order: P1 (SKILL.md + Context API) → P1 (Briefs) → P2 (Matching) → P2 (MCP) → P3 (Documentation only)
2. Do NOT implement P3 features (NL booking, RAG pipeline) — document only
3. Challenge any assumption that adds >2 hours to a feature
4. If OpenAI API is unavailable during development, mock `LlmClient` responses
5. Ensure all AI jobs are idempotent and have Sidekiq retry configured
6. Update `AIContextController#ai_feature_flags` as features are completed
7. Add token usage logging to `lograge` custom payload for observability
```
