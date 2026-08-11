FactoryBot.define do
  factory :mentor_profile do
    user { association :user, role: :mentor }
    bio { "Experienced software engineer with 10+ years in distributed systems" }
    expertise { ["Ruby on Rails", "System Design", "Career Growth"] }
  end
end
