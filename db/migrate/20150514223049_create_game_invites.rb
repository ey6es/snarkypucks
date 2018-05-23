class CreateGameInvites < ActiveRecord::Migration
  def change
    create_table :game_invites do |t|
      t.references :game, index: true, foreign_key: true
      t.references :sender, index: true, foreign_key: true
      t.string :message
      t.references :player, index: true, foreign_key: true
      t.string :email

      t.timestamps null: false
    end
    add_index :game_invites, :email
  end
end
