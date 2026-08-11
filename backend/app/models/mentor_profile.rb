class MentorProfile < ApplicationRecord
  belongs_to :user

  validates :bio, presence: true
  validates :expertise, presence: true
end
