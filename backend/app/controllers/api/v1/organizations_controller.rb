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

      # GET /api/v1/organizations/:organization_id/users
      # Returns all users for an organization (for the user picker)
      def users
        org = Organization.find(params[:organization_id])
        users = org.users.order(:name).map { |u| { id: u.id, name: u.name, email: u.email, role: u.role } }
        render json: users
      end
    end
  end
end
