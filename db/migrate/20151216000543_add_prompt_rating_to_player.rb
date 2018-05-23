class AddPromptRatingToPlayer < ActiveRecord::Migration
  def change
    add_column :players, :prompt_rating, :integer, null: false, default: 0
    add_index :players, :prompt_rating
  end
end
