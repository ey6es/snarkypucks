class RenamePromptType < ActiveRecord::Migration
  def change
    rename_column :prompts, :type, :prompt_type
  end
end
