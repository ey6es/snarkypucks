class RenameEmailInGameInvite < ActiveRecord::Migration
  def change
    rename_column :game_invites, :email, :fb_request_id
  end
end
