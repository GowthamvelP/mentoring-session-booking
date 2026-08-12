class User < ApplicationRecord
  include PgSearch::Model

  acts_as_tenant :organization

  has_one :mentor_profile, dependent: :destroy
  has_many :slots, foreign_key: :mentor_id, dependent: :destroy, inverse_of: :mentor
  has_many :bookings, foreign_key: :member_id, dependent: :destroy, inverse_of: :member
  has_many :notifications, dependent: :destroy

  has_secure_password validations: false # Stub auth — no password required

  enum :role, { member: "member", mentor: "mentor" }

  validates :email, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: roles.keys }

  # Trigram-based search scope for partial/fuzzy name matching
  # Uses GIN index with gin_trgm_ops for fast similarity lookups
  pg_search_scope :search_by_name,
                  against: :name,
                  using: {
                    trigram: {
                      threshold: 0.1
                    }
                  }

  scope :mentors, -> { where(role: :mentor) }
  scope :members, -> { where(role: :member) }
end
