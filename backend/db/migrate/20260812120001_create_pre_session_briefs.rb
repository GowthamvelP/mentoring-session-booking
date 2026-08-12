# frozen_string_literal: true

class CreatePreSessionBriefs < ActiveRecord::Migration[8.0]
  def change
    create_table :pre_session_briefs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :booking, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.text :content
      t.string :model_used
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens
      t.string :status, null: false, default: "pending"
      t.text :error_message
      t.timestamps
    end
  end
end
