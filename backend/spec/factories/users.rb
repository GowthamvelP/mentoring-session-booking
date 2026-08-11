FactoryBot.define do
  factory :user do
    organization
    name { "John Doe" }
    sequence(:email) { |n| "user#{n}@example.com" }
    role { :member }

    trait :mentor do
      role { :mentor }
      after(:create) do |user|
        create(:mentor_profile, user: user) unless user.mentor_profile
      end
    end

    trait :member do
      role { :member }
    end
  end
end
