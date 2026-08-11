# frozen_string_literal: true

# Stub authentication via request headers.
# In production, this would validate JWT tokens or session cookies.
# For this exercise, we trust X-User-Id and X-Org-Id headers.
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    user_id = request.headers["X-User-Id"]
    org_id = request.headers["X-Org-Id"]

    if user_id.blank? || org_id.blank?
      render json: { error: "Authentication required", details: { missing: "X-User-Id and X-Org-Id headers required" } }, status: :unauthorized
      return
    end

    Current.organization = Organization.find_by(id: org_id)
    unless Current.organization
      render json: { error: "Invalid organization", details: { org_id: "Organization not found" } }, status: :unauthorized
      return
    end

    Current.user = Current.organization.users.find_by(id: user_id)
    unless Current.user
      render json: { error: "Invalid user", details: { user_id: "User not found in organization" } }, status: :unauthorized
      return
    end
  end

  def current_user
    Current.user
  end

  def current_organization
    Current.organization
  end
end
