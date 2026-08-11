class AddMaxActiveBookingsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :organizations, :max_active_bookings, :integer, default: 5
    end
  end
end
