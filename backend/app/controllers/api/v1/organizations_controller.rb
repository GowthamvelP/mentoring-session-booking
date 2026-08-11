# frozen_string_literal: true

module Api
  module V1
    class OrganizationsController < ActionController::API
      # No authentication required — this is the org selector endpoint
      def index
        organizations = Organization.all.order(:name)
        render json: organizations.map { |org|
          { id: org.id, name: org.name, timezone: org.timezone }
        }
      end
    end
  end
end
