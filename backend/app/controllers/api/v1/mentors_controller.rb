# frozen_string_literal: true

module Api
  module V1
    class MentorsController < BaseController
      def index
        mentors = User.mentors.includes(:mentor_profile)
        pagy, records = pagy(mentors, limit: 20)

        render json: {
          data: MentorBlueprint.render_as_hash(records, view: :default),
          meta: pagy_metadata(pagy)
        }
      end
    end
  end
end
