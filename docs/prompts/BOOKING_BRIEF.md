# KIRO TASK: Pre-Session Briefs — Document or Implement?

## Context
The repository has a `BookingBriefJob` that generates pre-session briefs for mentors. Currently it is STUBBED — it generates a hardcoded markdown template. The schema (`pre_session_briefs` table), job idempotency, and Sidekiq retry are all production-ready.

## Current State (Verified from Repo)
- `app/jobs/booking_brief_job.rb` — `generate_with_llm(booking)` just calls `generate_stub_brief(booking)`
- `app/models/pre_session_brief.rb` — Schema has `content`, `model_used`, `prompt_tokens`, `completion_tokens`, `total_tokens`, `status`
- NO `LlmClient` service exists in `app/services/`
- NO OpenAI API key is guaranteed to be available during the MentorBook walkthrough

## Question for You (Kiro)
Should we:
1. **DOCUMENT ONLY** (5 min): Add a paragraph to README explaining the brief is stubbed for 48h MVP, with the 15-minute wiring path documented.
2. **IMPLEMENT** (30–45 min): Create `app/services/llm_client.rb`, wire it into `BookingBriefJob`, add tests, and update README.

## My Constraints
- MentorBook walkthrough is ~20 minutes. Demo risk matters.
- The evaluator sees MCP server, AI Context API, SKILL.md, and notifications as AI-native signals.
- I have approximately __ hours left before submission. (FILL THIS IN)

## If You Recommend IMPLEMENT
Create:
- `app/services/llm_client.rb` — Faraday-based client calling OpenAI chat completions
- Handle timeouts, token tracking, model metadata
- Update `BookingBriefJob#generate_with_llm` to call `LlmClient.generate_brief`
- Add `spec/services/llm_client_spec.rb` with VCR or mocked HTTP
- Update README AI section

## If You Recommend DOCUMENT ONLY
Add to README under AI-Native Architecture:
```markdown
### Pre-Session Briefs (Stubbed for MVP)
When a booking is confirmed, `BookingBriefJob` generates a personalized mentor 
brief via LLM. For the 48-hour MVP, this is stubbed with a template. The schema 
(`pre_session_briefs` table with token tracking columns), job idempotency, and 
Sidekiq retry are all production-ready. Wiring a real LLM (OpenAI GPT-4o-mini 
via `LlmClient` service) is a 15-minute change: swap `generate_stub_brief` for 
an API call, store tokens/model in existing columns, and handle timeouts with 
the existing retry logic.