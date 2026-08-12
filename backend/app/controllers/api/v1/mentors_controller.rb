# frozen_string_literal: true

module Api
  module V1
    class MentorsController < BaseController
      def index
        mentors = User.mentors.includes(:mentor_profile)

        # Simple search/filter by name or expertise
        if params[:search].present?
          search_term = "%#{params[:search].downcase}%"
          mentors = mentors.joins(:mentor_profile).where(
            "LOWER(users.name) LIKE :term OR LOWER(array_to_string(mentor_profiles.expertise, ' ')) LIKE :term",
            term: search_term
          )
        end

        pagy, records = pagy(mentors, limit: 20)

        render json: {
          data: MentorBlueprint.render_as_hash(records, view: :default),
          meta: pagy_metadata(pagy)
        }
      end
    end
  end
end
