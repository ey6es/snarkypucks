class Track < ActiveRecord::Base
  belongs_to :creator, class_name: "Player"
  has_many :revisions, class_name: "TrackRevision"
  has_one :published_revision, class_name: "TrackRevision"
  
  before_destroy :destroy_unused_revisions
  
  private
    def destroy_unused_revisions
      self.revisions.each do |revision|
        revision.disconnect
      end
    end
end
