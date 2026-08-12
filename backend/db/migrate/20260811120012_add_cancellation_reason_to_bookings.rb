# frozen_string_literal: true

class AddCancellationReasonToBookings < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :bookings, :cancellation_reason, :text
    end
  end
end
