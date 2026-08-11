# frozen_string_literal: true

class OrganizationBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :timezone
end
