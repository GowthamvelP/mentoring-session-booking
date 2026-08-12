# frozen_string_literal: true

class AddTrigramSearchIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Step 1: Enable pg_trgm extension (idempotent)
    safety_assured do
      execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    end

    # Step 2: Remove old BTREE index on LOWER(name)
    remove_index :users, name: "index_users_on_lower_name", if_exists: true

    # Step 3: Add GIN trigram index on users.name
    add_index :users, :name,
              name: "index_users_on_name_trgm",
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently

    # Step 4: Add GIN index on mentor_profiles.expertise (array)
    add_index :mentor_profiles, :expertise,
              name: "index_mentor_profiles_on_expertise_gin",
              using: :gin,
              algorithm: :concurrently
  end

  def down
    remove_index :mentor_profiles, name: "index_mentor_profiles_on_expertise_gin", if_exists: true
    remove_index :users, name: "index_users_on_name_trgm", if_exists: true

    # Restore original BTREE index
    safety_assured do
      add_index :users, "LOWER(name)",
                name: "index_users_on_lower_name",
                algorithm: :concurrently
    end
  end
end
