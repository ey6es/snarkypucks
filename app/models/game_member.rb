class GameMember < ActiveRecord::Base
  belongs_to :game
  belongs_to :player
  
  after_create :start_full_game
  after_destroy :destroy_empty_game
  
  private
    def start_full_game
      if self.game.game_members.count == self.game.max_players
        self.game.start
      end
    end
  
    def destroy_empty_game
      if !self.game.being_destroyed? && self.game.game_members.count == 0
        self.game.destroy
      end
    end
end
