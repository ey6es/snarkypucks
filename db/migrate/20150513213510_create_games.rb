class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.string :title
      t.references :track_revision, index: true, foreign_key: true
      t.integer :turn_interval
      t.boolean :early_turns
      t.integer :min_players
      t.integer :max_players
      t.boolean :open_to_all
      t.boolean :open_to_friends
      t.text :update

      t.timestamps null: false
    end
  end
end
