class AddStatsToPlayer < ActiveRecord::Migration
  def change
    add_column :players, :games_played, :integer, null: false, default: 0
    add_column :players, :games_won, :integer, null: false, default: 0
    add_column :players, :prompts_answered, :integer, null: false, default: 0
    add_column :players, :prompts_won, :integer, null: false, default: 0
    add_column :players, :votes_received, :integer, null: false, default: 0
    add_column :players, :rating, :integer, null: false, default: 0
    add_index :players, :games_played
    add_index :players, :games_won
    add_index :players, :prompts_answered
    add_index :players, :prompts_won
    add_index :players, :votes_received
    add_index :players, :rating
    add_index :prompt_type_ratings, [:player_id, :prompt_type], unique: true
  end
end
