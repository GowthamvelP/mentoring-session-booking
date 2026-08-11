class AddBufferMinutesToSlots < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :slots, :buffer_minutes, :integer, default: 15
    end
  end
end
