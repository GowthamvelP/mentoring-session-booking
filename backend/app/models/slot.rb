class Slot < ApplicationRecord
  acts_as_tenant :organization

  belongs_to :mentor, class_name: "User", inverse_of: :slots
  has_one :booking, dependent: :restrict_with_error

  enum :status, { available: "available", booked: "booked" }

  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, presence: true
  validate :end_after_start

  scope :available, -> { where(status: :available) }
  scope :future, -> { where("start_time > ?", Time.current) }
  scope :for_date_range, ->(start_date, end_date) {
    where(start_time: start_date.beginning_of_day..end_date.end_of_day)
  }

  private

  def end_after_start
    return if end_time.blank? || start_time.blank?
    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end
end
