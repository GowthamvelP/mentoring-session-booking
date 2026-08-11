class Booking < ApplicationRecord
  acts_as_tenant :organization

  belongs_to :slot
  belongs_to :member, class_name: "User", inverse_of: :bookings

  enum :status, { confirmed: "confirmed", cancelled: "cancelled", completed: "completed" }

  validates :idempotency_key, presence: true, uniqueness: true
  validates :status, presence: true
  validates :booked_at, presence: true

  scope :active, -> { where(status: :confirmed) }
  scope :by_slot_time, -> { joins(:slot).order("slots.start_time DESC") }
end
