class AddFinishingToGame < ActiveRecord::Migration
  def change
    add_column :games, :finishing, :boolean, null: false, default: false
  end
end
