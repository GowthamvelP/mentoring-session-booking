# frozen_string_literal: true

# Sets the ActsAsTenant current tenant from Current.organization.
# Must be included AFTER Authenticatable (which sets Current.organization).
module Tenantable
  extend ActiveSupport::Concern

  included do
    before_action :set_tenant!, if: -> { Current.organization.present? }
  end

  private

  def set_tenant!
    ActsAsTenant.current_tenant = Current.organization
  end
end
