# frozen_string_literal: true

module Api
  module V1
    class MentorsController < BaseController
      def index
        mentors = User.mentors.includes(:mentor_profile)

        if params[:search].present?
          search_term = params[:search].strip

          # GIN trigram search on name (via pg_search)
          name_match_ids = mentors.search_by_name(search_term).select(:id)

          # GIN array search on expertise (ILIKE for partial matching)
          expertise_match_ids = mentors.joins(:mentor_profile).where(
            "EXISTS (SELECT 1 FROM unnest(mentor_profiles.expertise) AS e WHERE e ILIKE ?)",
            "%#{search_term}%"
          ).select(:id)

          # Combine results with OR
          mentors = mentors.where(id: name_match_ids).or(mentors.where(id: expertise_match_ids))
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
