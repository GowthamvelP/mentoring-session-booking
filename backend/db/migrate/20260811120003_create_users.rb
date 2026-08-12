class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :email, null: false
      t.string :name, null: false
      t.string :role, null: false, default: 'member'
      t.string :password_digest

      t.timestamps
    end

    add_index :users, [ :organization_id, :email ], unique: true
  end
end
