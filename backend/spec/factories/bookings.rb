FactoryBot.define do
  factory :booking do
    association :slot, :booked
    association :member, factory: [:user, :member]
    organization { slot.organization }
    idempotency_key { SecureRandom.uuid }
    status { :confirmed }
    booked_at { Time.current }

    trait :cancelled do
      status { :cancelled }
      cancelled_at { Time.current }
    end
  end
end
