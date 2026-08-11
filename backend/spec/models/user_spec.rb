require "rails_helper"

RSpec.describe User, type: :model do
  let(:organization) { create(:organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe "associations" do
    it { is_expected.to belong_to(:organization).without_validating_presence }
    it { is_expected.to have_one(:mentor_profile).dependent(:destroy) }
    it { is_expected.to have_many(:slots).with_foreign_key(:mentor_id).dependent(:destroy) }
    it { is_expected.to have_many(:bookings).with_foreign_key(:member_id).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user, organization: organization) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:role) }

    it "validates email uniqueness scoped to organization" do
      create(:user, email: "duplicate@example.com", organization: organization)
      user = build(:user, email: "duplicate@example.com", organization: organization)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("has already been taken")
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:role).with_values(member: "member", mentor: "mentor").backed_by_column_of_type(:string) }
  end

  describe "scopes" do
    let!(:mentor) { create(:user, :mentor, organization: organization) }
    let!(:member) { create(:user, :member, organization: organization) }

    it ".mentors returns only mentors" do
      expect(User.mentors).to include(mentor)
      expect(User.mentors).not_to include(member)
    end

    it ".members returns only members" do
      expect(User.members).to include(member)
      expect(User.members).not_to include(mentor)
    end
  end
end
