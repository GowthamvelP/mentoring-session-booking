class CreateBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :bookings, id: :uuid do |t|
      t.references :slot, type: :uuid, null: false, foreign_key: true
      t.references :member, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :status, null: false, default: 'confirmed'
      t.string :idempotency_key, null: false
      t.datetime :booked_at, null: false
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :bookings, :idempotency_key, unique: true
    add_index :bookings, :slot_id
  end
end
