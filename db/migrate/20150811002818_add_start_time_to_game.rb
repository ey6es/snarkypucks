class AddStartTimeToGame < ActiveRecord::Migration
  def change
    add_column :games, :start_time, :datetime
    add_column :games, :turn_number, :integer
  end
end
