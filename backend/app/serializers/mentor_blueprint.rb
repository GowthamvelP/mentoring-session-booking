# frozen_string_literal: true

# Serializer for mentor data.
# Never expose internal fields (organization_id, password_digest).
# The :default view is used for mentor listing cards.
class MentorBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :email, :role

  view :default do
    field :bio do |user|
      user.mentor_profile&.bio
    end
    field :expertise do |user|
      user.mentor_profile&.expertise || []
    end
  end
end
