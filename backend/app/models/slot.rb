class Slot < ApplicationRecord
  acts_as_tenant :organization

  belongs_to :mentor, class_name: "User", inverse_of: :slots
  has_one :booking, dependent: :restrict_with_error

  enum :status, { available: "available", booked: "booked" }

  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, presence: true
  validate :end_after_start
  validate :no_buffer_overlap, on: :create

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

  def no_buffer_overlap
    return if mentor_id.blank? || start_time.blank? || end_time.blank?

    buffer = (buffer_minutes || 15).minutes
    conflicting = Slot.where(mentor_id: mentor_id)
                      .where.not(id: id)
                      .where("start_time < ? AND end_time > ?",
                             end_time + buffer,
                             start_time - buffer)
    if conflicting.exists?
      errors.add(:start_time, "conflicts with another slot (including #{buffer_minutes || 15} min buffer)")
    end
  end
end
