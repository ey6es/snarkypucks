class CreatePromptTypeRatings < ActiveRecord::Migration
  def change
    create_table :prompt_type_ratings do |t|
      t.references :player, index: true, foreign_key: true
      t.string :prompt_type
      t.integer :value
      t.integer :total

      t.timestamps null: false
    end
    add_index :prompt_type_ratings, :prompt_type
  end
end
