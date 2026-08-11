class CreateMentorProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :mentor_profiles, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.text :bio, null: false
      t.string :expertise, array: true, null: false, default: []

      t.timestamps
    end
  end
end
