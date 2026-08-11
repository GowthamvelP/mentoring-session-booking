FactoryBot.define do
  factory :organization do
    name { "Acme Corp" }
    timezone { "America/New_York" }

    trait :pacific do
      name { "Pacific Inc" }
      timezone { "America/Los_Angeles" }
    end

    trait :with_booking_limit do
      max_active_bookings { 3 }
    end
  end
end
