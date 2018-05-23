class AddCompletedTutorialToPlayer < ActiveRecord::Migration
  def change
    add_column :players, :completed_tutorial, :boolean
  end
end
