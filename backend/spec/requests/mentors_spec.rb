require "rails_helper"

RSpec.describe "Mentors API", type: :request do
  let(:organization) { create(:organization) }
  let!(:mentor) { create(:user, :mentor, organization: organization) }
  let(:member) { create(:user, :member, organization: organization) }

  let(:headers) { { "X-User-Id" => member.id, "X-Org-Id" => organization.id } }

  describe "GET /api/v1/mentors" do
    it "returns paginated mentors for the organization" do
      get "/api/v1/mentors", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].first["name"]).to eq(mentor.name)
      expect(json["meta"]).to include("current_page", "total_pages", "total_count")
    end

    it "returns 401 without auth" do
      get "/api/v1/mentors"
      expect(response).to have_http_status(:unauthorized)
    end

    it "only returns mentors for the current organization" do
      other_org = create(:organization, name: "Other Org")
      create(:user, :mentor, organization: other_org)

      get "/api/v1/mentors", headers: headers

      json = JSON.parse(response.body)
      expect(json["data"].length).to eq(1)
      expect(json["data"].first["id"]).to eq(mentor.id)
    end

    it "includes pagination metadata" do
      get "/api/v1/mentors", headers: headers

      json = JSON.parse(response.body)
      expect(json["meta"]["current_page"]).to eq(1)
      expect(json["meta"]["total_count"]).to be >= 1
      expect(json["meta"]["per_page"]).to be_present
    end

    context "with search filter" do
      let!(:mentor2) { create(:user, :mentor, organization: organization, name: "Jane Python Expert") }

      before do
        mentor.mentor_profile.update!(expertise: ["Ruby on Rails", "System Design"])
        mentor2.mentor_profile.update!(expertise: ["Python", "Machine Learning"])
      end

      it "filters mentors by name" do
        get "/api/v1/mentors", params: { search: mentor.name.split.first.downcase }, headers: headers
        json = JSON.parse(response.body)
        expect(json["data"].length).to be >= 1
        expect(json["data"].map { |m| m["id"] }).to include(mentor.id)
      end

      it "filters mentors by expertise" do
        get "/api/v1/mentors", params: { search: "python" }, headers: headers
        json = JSON.parse(response.body)
        expect(json["data"].length).to be >= 1
        expect(json["data"].map { |m| m["id"] }).to include(mentor2.id)
      end

      it "returns empty array for no matches" do
        get "/api/v1/mentors", params: { search: "nonexistenttermxyz" }, headers: headers
        json = JSON.parse(response.body)
        expect(json["data"]).to eq([])
      end
    end
  end
end
