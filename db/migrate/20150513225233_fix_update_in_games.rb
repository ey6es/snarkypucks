class FixUpdateInGames < ActiveRecord::Migration
  def change
    rename_column :games, :update, :results
    add_column :games, :last_move_time, :datetime
  end
end
