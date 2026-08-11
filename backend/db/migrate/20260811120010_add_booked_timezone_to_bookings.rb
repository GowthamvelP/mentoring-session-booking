class AddBookedTimezoneToBookings < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :bookings, :booked_timezone, :string
    end
  end
end
