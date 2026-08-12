# frozen_string_literal: true

# PreSessionBrief stores AI-generated session preparation notes for mentors.
# Generated asynchronously via BookingBriefJob after a booking is confirmed.
# Architecture: BookingService -> BookingBriefJob -> LlmClient -> PreSessionBrief
class PreSessionBrief < ApplicationRecord
  belongs_to :booking

  validates :content, presence: true, if: -> { status == "generated" }

  scope :generated, -> { where(status: "generated") }
  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }
end
