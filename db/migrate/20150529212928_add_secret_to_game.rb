class AddSecretToGame < ActiveRecord::Migration
  def change
    add_column :games, :secret, :text
  end
end
