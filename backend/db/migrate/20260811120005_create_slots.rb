class CreateSlots < ActiveRecord::Migration[8.0]
  def change
    create_table :slots, id: :uuid do |t|
      t.references :mentor, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :status, null: false, default: 'available'

      t.timestamps
    end

    add_index :slots, [:mentor_id, :start_time], unique: true
    add_index :slots, [:mentor_id, :status, :start_time]
    add_index :slots, :start_time
  end
end
