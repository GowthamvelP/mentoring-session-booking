class User < ApplicationRecord
  acts_as_tenant :organization

  has_one :mentor_profile, dependent: :destroy
  has_many :slots, foreign_key: :mentor_id, dependent: :destroy, inverse_of: :mentor
  has_many :bookings, foreign_key: :member_id, dependent: :destroy, inverse_of: :member

  has_secure_password validations: false # Stub auth — no password required

  enum :role, { member: "member", mentor: "mentor" }

  validates :email, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: roles.keys }

  scope :mentors, -> { where(role: :mentor) }
  scope :members, -> { where(role: :member) }
end
