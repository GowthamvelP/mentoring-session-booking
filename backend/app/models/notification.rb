# frozen_string_literal: true

class Notification < ApplicationRecord
  acts_as_tenant :organization

  belongs_to :user
  belongs_to :booking, optional: true

  validates :notification_type, presence: true
  validates :title, presence: true
  validates :body, presence: true

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc).limit(20) }
end
