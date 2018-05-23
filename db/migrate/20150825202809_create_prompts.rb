class CreatePrompts < ActiveRecord::Migration
  def change
    create_table :prompts do |t|
      t.string :type
      t.string :inline_url
      t.string :full_url
      t.text :content
      t.references :game, index: true, foreign_key: true

      t.timestamps null: false
    end
    add_index :prompts, :type
  end
end
