class AddTimezoneToUsers < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :users, :timezone, :string
    end
  end
end
