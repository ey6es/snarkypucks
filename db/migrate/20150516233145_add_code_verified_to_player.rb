class AddCodeVerifiedToPlayer < ActiveRecord::Migration
  def change
    add_column :players, :code, :string
    add_index :players, :code
    add_column :players, :verified, :boolean
    
    remove_column :sessions, :expires
  end
end
