# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mentors Search API", type: :request do
  let(:organization) { create(:organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:headers) { { "X-User-Id" => member.id, "X-Org-Id" => organization.id } }

  # Create mentors with distinctive names and expertise
  let!(:john) do
    create(:user, :mentor, organization: organization, name: "John Smith").tap do |u|
      u.mentor_profile.update!(expertise: [ "Ruby on Rails", "System Design", "PostgreSQL" ])
    end
  end

  let!(:jane) do
    create(:user, :mentor, organization: organization, name: "Jane Anderson").tap do |u|
      u.mentor_profile.update!(expertise: [ "Python", "Machine Learning", "Data Science" ])
    end
  end

  let!(:robert) do
    create(:user, :mentor, organization: organization, name: "Robert Johnson").tap do |u|
      u.mentor_profile.update!(expertise: [ "JavaScript", "React", "Node.js" ])
    end
  end

  describe "GET /api/v1/mentors with search" do
    context "name-based trigram search" do
      it "finds mentors by partial name (3+ characters)" do
        get "/api/v1/mentors", params: { search: "john" }, headers: headers

        json = JSON.parse(response.body)
        ids = json["data"].map { |m| m["id"] }
        # Should match "John Smith" and/or "Robert Johnson" via trigram similarity
        expect(ids).to include(john.id)
      end

      it "finds mentors by prefix match" do
        get "/api/v1/mentors", params: { search: "jane" }, headers: headers

        json = JSON.parse(response.body)
        ids = json["data"].map { |m| m["id"] }
        expect(ids).to include(jane.id)
      end

      it "performs case-insensitive name matching" do
        get "/api/v1/mentors", params: { search: "JOHN" }, headers: headers

        json = JSON.parse(response.body)
        ids = json["data"].map { |m| m["id"] }
        expect(ids).to include(john.id)
      end

      it "returns empty results for non-matching name" do
        get "/api/v1/mentors", params: { search: "zzzznonexistent" }, headers: headers

        json = JSON.parse(response.body)
        expect(json["data"]).to eq([])
      end
    end

    context "expertise-based search" do
      it "finds mentors by expertise keyword" do
        get "/api/v1/mentors", params: { search: "python" }, headers: headers

        json = JSON.parse(response.body)
        ids = json["data"].map { |m| m["id"] }
        expect(ids).to include(jane.id)
      end

      it "finds mentors by partial expertise match" do
        get "/api/v1/mentors", params: { search: "machine" }, headers: headers

        json = JSON.parse(response.body)
        ids = json["data"].map { |m| m["id"] }
        expect(ids).to include(jane.id)
      end

      it "performs case-insensitive expertise matching" do
        get "/api/v1/mentors", params: { search: "REACT" }, headers: headers

        json = JSON.parse(response.body)
        ids = json["data"].map { |m| m["id"] }
        expect(ids).to include(robert.id)
      end

      it "matches expertise containing the search term" do
        get "/api/v1/mentors", params: { search: "rails" }, headers: headers

        json = JSON.parse(response.body)
        ids = json["data"].map { |m| m["id"] }
        expect(ids).to include(john.id)
      end
    end

    context "blank or absent search" do
      it "returns all mentors when search is blank" do
        get "/api/v1/mentors", params: { search: "" }, headers: headers

        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(3)
      end

      it "returns all mentors when search param is absent" do
        get "/api/v1/mentors", headers: headers

        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(3)
      end
    end

    context "response format" do
      it "preserves data and meta structure with search" do
        get "/api/v1/mentors", params: { search: "john" }, headers: headers

        json = JSON.parse(response.body)
        expect(json).to have_key("data")
        expect(json["data"]).to be_an(Array)
        expect(json).to have_key("meta")
        expect(json["meta"]).to include("current_page", "total_pages", "total_count", "per_page")
      end

      it "preserves data and meta structure without search" do
        get "/api/v1/mentors", headers: headers

        json = JSON.parse(response.body)
        expect(json).to have_key("data")
        expect(json["data"]).to be_an(Array)
        expect(json).to have_key("meta")
        expect(json["meta"]).to include("current_page", "total_pages", "total_count", "per_page")
      end
    end

    context "combined name and expertise results" do
      it "returns unique mentors matching either name or expertise" do
        # "ruby" matches John's expertise ("Ruby on Rails")
        get "/api/v1/mentors", params: { search: "ruby" }, headers: headers

        json = JSON.parse(response.body)
        ids = json["data"].map { |m| m["id"] }
        expect(ids).to include(john.id)
        # Should not have duplicates
        expect(ids.length).to eq(ids.uniq.length)
      end
    end
  end
end
