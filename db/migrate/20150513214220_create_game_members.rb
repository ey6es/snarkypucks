class CreateGameMembers < ActiveRecord::Migration
  def change
    create_table :game_members do |t|
      t.references :game, index: true, foreign_key: true
      t.references :player, index: true, foreign_key: true
      t.text :move

      t.timestamps null: false
    end
  end
end
