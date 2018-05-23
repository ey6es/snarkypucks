class TrackRevision < ActiveRecord::Base
  belongs_to :track
  has_many :games
  
  def disconnect
    self.games.empty? ? destroy : update(track_id: nil)
  end
  
  def maybe_destroy
    destroy unless self.track_id || !self.games.empty?
  end
end
