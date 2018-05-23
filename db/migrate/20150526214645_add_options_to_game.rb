class AddOptionsToGame < ActiveRecord::Migration
  def change
    add_column :games, :moves_per_turn, :integer
    add_column :games, :move_distance, :float
    add_column :games, :prompts_per_turn, :integer
  end
end
