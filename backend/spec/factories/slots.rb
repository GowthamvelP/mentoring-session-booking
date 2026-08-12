FactoryBot.define do
  factory :slot do
    association :mentor, factory: [ :user, :mentor ]
    organization { mentor.organization }
    start_time { 1.day.from_now.beginning_of_hour }
    end_time { start_time + 1.hour }
    status { :available }

    trait :booked do
      status { :booked }
    end

    trait :past do
      start_time { 1.day.ago.beginning_of_hour }
      end_time { start_time + 1.hour }
    end

    trait :soon do
      start_time { 30.minutes.from_now }
      end_time { start_time + 1.hour }
    end
  end
end
