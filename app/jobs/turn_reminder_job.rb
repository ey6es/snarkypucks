require "net/http"

class TurnReminderJob < ActiveJob::Base
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game && !game.finished
    
    no_players_moved = (game.last_move_time != game.next_move_time)
    
    game.game_members.each do |game_member|
      if no_players_moved || !game_member.move
        if game_member.player.notification_email
          begin
            Notifications.turn_reminder(game_member.player).deliver_now
          rescue StandardError => e
            logger.warn e.message
          end
        end
        if game_member.player.push_endpoint
          begin
            endpoint = game_member.player.push_endpoint
            base_url = "https://android.googleapis.com/gcm/send"
            if endpoint.start_with? base_url
              uri = URI(base_url)
              Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
                req = Net::HTTP::Post.new(base_url)
                req.set_content_type "application/json"
                req["Authorization"] = "key=#{Rails.configuration.x.gcm_app_key}"
                req.body = "{\"registration_ids\":[\"#{endpoint.rpartition("/")[2]}\"]}"
                response = http.request req
                unless response.is_a? Net::HTTPOK
                  logger.warn response.body
                end
              end
            end
          rescue StandardError => e
            logger.warn e.message
          end
        end
      end
    end
  end
end
