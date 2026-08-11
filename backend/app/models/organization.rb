class Organization < ApplicationRecord
  has_many :users, dependent: :destroy

  validates :name, presence: true
  validates :timezone, presence: true
  validates :max_active_bookings, numericality: { greater_than: 0 }, allow_nil: true
end
