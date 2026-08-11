# frozen_string_literal: true

module Api
  module V1
    class AuthController < ActionController::API
      # Stub auth — select org + user to establish context.
      # In production this would validate credentials.
      def select_org
        org = Organization.find_by(id: params[:organization_id])
        unless org
          render json: { error: "Organization not found" }, status: :not_found
          return
        end

        user = org.users.find_by(id: params[:user_id])
        unless user
          render json: { error: "User not found in organization" }, status: :not_found
          return
        end

        render json: {
          organization: { id: org.id, name: org.name, timezone: org.timezone },
          user: { id: user.id, name: user.name, email: user.email, role: user.role }
        }
      end
    end
  end
end
