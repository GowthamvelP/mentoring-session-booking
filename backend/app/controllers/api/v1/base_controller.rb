# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Authenticatable
      include Tenantable
      include Pagy::Method

      # Consistent error handling
      rescue_from ActiveRecord::RecordNotFound do |e|
        render json: { error: "Resource not found", details: { resource: e.model } }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { error: "Validation failed", details: e.record.errors.messages }, status: :unprocessable_entity
      end

      rescue_from ActsAsTenant::Errors::NoTenantSet do |_e|
        render json: { error: "Organization context required" }, status: :unauthorized
      end

      private

      def render_error(message, status:, details: nil)
        render json: { error: message, details: details }.compact, status: status
      end

      # Pagy metadata helper for pagination
      def pagy_metadata(pagy)
        {
          current_page: pagy.page,
          total_pages: pagy.pages,
          total_count: pagy.count,
          per_page: pagy.limit
        }
      end
    end
  end
end
