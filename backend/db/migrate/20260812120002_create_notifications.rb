# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :booking, type: :uuid, foreign_key: true
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.boolean :read, null: false, default: false
      t.timestamps
    end

    add_index :notifications, [ :user_id, :read, :created_at ], name: "index_notifications_on_user_read_created"
  end
end
