class AddGuidToPrompt < ActiveRecord::Migration
  def change
    add_column :prompts, :guid, :string
    add_index :prompts, :guid
    add_column :prompts, :expires, :datetime
    add_index :prompts, :expires
  end
end
