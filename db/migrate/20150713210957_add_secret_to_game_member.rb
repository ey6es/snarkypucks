class AddSecretToGameMember < ActiveRecord::Migration
  def change
    add_column :game_members, :secret, :text
  end
end
