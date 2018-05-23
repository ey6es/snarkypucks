class AddIndicesToGame < ActiveRecord::Migration
  def change
    add_index :games, :start_time
    add_index :games, :open_to_all
  end
end
