# frozen_string_literal: true

# Belt-and-suspenders safety: even if the pessimistic lock has a bug,
# the DB constraint prevents two active bookings for the same slot.
class AddUniqueIndexBookingsActiveSlot < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index :bookings, :slot_id,
                unique: true,
                where: "status != 'cancelled'",
                name: "index_bookings_on_slot_id_active_unique",
                algorithm: :concurrently
    end
  end
end
