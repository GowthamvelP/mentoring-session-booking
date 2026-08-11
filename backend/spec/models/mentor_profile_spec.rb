require "rails_helper"

RSpec.describe MentorProfile, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:bio) }
    it { is_expected.to validate_presence_of(:expertise) }
  end
end
