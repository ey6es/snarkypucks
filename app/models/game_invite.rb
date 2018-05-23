require "net/http"

class GameInvite < ActiveRecord::Base
  belongs_to :game, inverse_of: :game_invites
  belongs_to :sender, class_name: "Player", inverse_of: :sent_game_invites
  belongs_to :player, inverse_of: :game_invites
  
  before_destroy :maybe_cancel_facebook_request
  
  private
  
    def maybe_cancel_facebook_request
      return unless fb_request_id
      base_url = "https://graph.facebook.com/v2.5/" 
      creds = "?access_token=#{Rails.configuration.x.fb_app_id}|#{Rails.configuration.x.fb_app_secret}"
      uri = URI(base_url)
      Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
        http.request Net::HTTP::Delete.new(base_url + "#{fb_request_id}_#{player.facebook_id}" + creds)
      end
    end
  
end
