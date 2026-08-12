# frozen_string_literal: true

class AddSearchAndPerformanceIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      # Search optimization: btree index on lower(name) for LIKE queries
      add_index :users, "LOWER(name)", name: "index_users_on_lower_name", algorithm: :concurrently

      # Booking queries: member's active bookings (used in limit check + sessions)
      add_index :bookings, [ :member_id, :status ], name: "index_bookings_on_member_id_and_status", algorithm: :concurrently

      # Session queries: bookings ordered by slot time (used in sessions endpoint)
      add_index :bookings, [ :member_id, :organization_id, :status ], name: "index_bookings_on_member_org_status", algorithm: :concurrently
    end
  end
end
