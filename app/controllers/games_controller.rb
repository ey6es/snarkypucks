require "net/http"

class GamesController < ApplicationController

  # The number of open games per page.
  OPEN_GAMES_PER_PAGE = 4

  # The number of rankings per page.
  RANKINGS_PER_PAGE = 8

  # The offset to apply to ratings to make them seem less depressing.
  RATING_OFFSET = 1200

  skip_before_action :verify_authenticity_token, only: :canvas
  skip_before_action :require_login, only: [:canvas, :app]
  skip_before_action :require_name, only: :app
  after_action :allow_iframe, only: :canvas
  
  before_action :require_admin
  skip_before_action :require_admin, only: [:joined, :open, :create, :join, :leave, :create_invite,
    :canvas, :app, :notices, :last_turn, :complete_tutorial, :game_invite_answer, :move,
    :prompt_rankings, :game_rankings, :personal_stats]
   
  def index
    @limit = 20
    @offset = params[:offset] || 0
    @count = Game.count
    @games = Game.includes(:game_members).select(:id, :title, :created_at)
      .order(:id).limit(@limit).offset(@offset)
  end
  
  def joined
    data = []
    @player.games.includes(:track_revision, :players).each do |game|
      data.push game.json_info
    end
    render json: data
  end
  
  def open
    count = open_game_count
    offset = OPEN_GAMES_PER_PAGE * params[:page].to_i
    data = { info: [], continues: count > offset + OPEN_GAMES_PER_PAGE }
    games = Game.includes(:track_revision, :players)
      .where("start_time is not null")
      .where(open_to_all: true)
      .order(:start_time)
      .limit(OPEN_GAMES_PER_PAGE)
      .offset(offset)
    games.each do |game|
      info = game.json_info
      info[:joined] = game.players.exists? @player
      data[:info].push info
    end
    render json: data
  end
  
  def create
    @game = Game.new
    configure_game
    @game.players << @player
    
    TurnReminderJob.set(wait_until: @game.start_time + (@game.turn_interval *
      Game::SECONDS_PER_MINUTE * Game::TURN_REMINDER_POINT).to_i).perform_later(@game.id)
    
    respond_to do |format|
      format.html { redirect_to @game, notice: "Game created." }
      format.json { render plain: "success" }
    end
  end
  
  def new
    @game = Game.new
    @game.min_players = Game::MIN_MIN_PLAYERS
    @game.max_players = Game::MAX_MAX_PLAYERS
    @game.moves_per_turn = Game::DEFAULT_MOVES_PER_TURN
    @game.move_distance = Game::DEFAULT_MOVE_DISTANCE
    @game.prompts_per_turn = Game::DEFAULT_PROMPTS_PER_TURN
    get_published_tracks
    render action: "show"
  end
  
  def show
    begin
      @game = Game.includes(game_members: :player, game_invites: [:player, :sender]).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        redirect_to games_path
        return
    end
    get_published_tracks
  end
  
  def update
    @game = Game.find(params[:id])
    configure_game
    redirect_to :back, notice: "Game updated."
  end
  
  def destroy
    Game.find(params[:id]).destroy
    redirect_to :back, notice: "Game deleted."
  end
  
  def join
    game = Game.find(params[:id])
    @player.game_invites.find_by(game_id: game.id).try(:destroy)
    if !(game.open_to_all || @player.admin)
      report_error "Access denied."
      return
    end
    game.with_lock do 
      if game.started?
        report_error "Sorry, game filled up; please try again."
        return
      end
      if game.players.exists? @player
        report_error "You've already joined that game."
        return
      end
      game.players << @player
    end
    report_success "Joined game."
  end
  
  def leave
    @game = Game.find(params[:id])
    @game.with_lock do
      @game.players.destroy(@player)
      report_success "Left game."
    end
  end
  
  def create_invite
    @game = Game.find(params[:id])
    if @game.started?
      report_error "Game already started."
      return
    end
    state = params[:game_invite]
    fb_response = state[:fb_response]
    sanitized_message = Player.sanitize(state[:message])
    unless !fb_response || fb_response.empty?
      response = JSON.parse(fb_response)
      request_id = response["request"]
      response["to"].each do |user_id|
        email = Player::FACEBOOK_PREFIX + user_id
        player = Player.find_by(email: email)
        unless player
          password = SecureRandom.base64
          player = Player.create(email: email, password: password, password_confirmation: password, verified: true)
        end
        @game.game_invites.create(sender_id: @player.id, message: sanitized_message,
          player_id: player.id, fb_request_id: request_id)
      end
      report_success "Player(s) invited."
      return
    end
    name = Player.process_name(state[:name])
    if name.empty?
      email = state[:email]
      unless Player.valid_email?(email)
        report_error "Please enter either a name or a valid email address."
        return
      end
      player = Player.find_by(email: email)
      unless player
        password = SecureRandom.base64
        player = Player.create(email: email, password: password, password_confirmation: password, code: SecureRandom.base64)
        Notifications.invite(player, "Come join me in a game of Snarky Pucks!  " + sanitized_message).deliver_now
      end
    else
      player = Player.find_by(name: name)
      unless player
        report_error "Player not found."
        return
      end
    end
    if @game.players.exists?(player.id)
      report_error "Player already in game."
      return
    end
    if @game.game_invites.exists?(player_id: player.id)
      report_error "Player already invited."
      return
    end
    @game.game_invites.create(sender_id: @player.id, message: sanitized_message, player_id: player.id)
    report_success "Player invited."
  end
  
  def new_invite
  end
  
  def remove_member
    @game = Game.find(params[:id])
    @game.game_members.find_by(player_id: params[:player_id]).destroy
    redirect_to :back, notice: "Removed player."
  end
  
  def rescind_invite
    @game = Game.find(params[:id])
    @game.game_invites.find_by(player_id: params[:player_id]).destroy
    redirect_to :back, notice: "Rescinded invite."
  end
  
  def canvas
    @mobile = true
    @canvas = true
    session[:test] = "test"
    render action: "app"
    request = params[:signed_request]
    return unless request
    parts = request.split(".")
    expected_signature = Base64.urlsafe_decode64(parts[0] + "=")
    signature = OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), Rails.configuration.x.fb_app_secret, parts[1])
    if signature != expected_signature
      raise "Invalid signature."
    end
    payload = parts[1].gsub("-", "+").gsub("_", "/") + "="
    data = JSON.parse(Base64.decode64(payload))
    request_ids = params["request_ids"]
    return unless request_ids
    user_id = data["user_id"]
    oauth_token = data["oauth_token"]
    unless user_id && oauth_token
      puts "Request id, but no user id? #{request_ids} #{data}"
      return
    end
    player = Player.find_by(email: Player::FACEBOOK_PREFIX + user_id)
    return unless player
    base_url = "https://graph.facebook.com/v2.3/" 
    creds = "_" + user_id + "?access_token=" + oauth_token
    uri = URI(base_url)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      request_ids.split(",").each do |request_id|
        http.request Net::HTTP::Delete.new(base_url + request_id + creds)
      end  
    end
  end
  
  def app
    @mobile = true
    @canvas = false
    session[:test] = "test"
    get_login
  end
  
  def notices
    data = { playerName: @player.name, joinedGames: 0, openGames: open_game_count, notices: [] }
    unless @player.completed_tutorial
      data[:notices].push({ type: "tutorial" })
    end
    @player.game_members.includes(:game).each do |game_member|
      game = game_member.game
      game.with_lock do
        if game.maybe_execute_turn || (!game_member.move && game.results)
          data[:notices].push create_game_notice(game)
        end
        data[:joinedGames] += 1 unless game.destroyed?
      end
    end
    @player.game_invites.includes(game: [:track_revision, :players], sender: []).each do |invite|
      game = invite.game
      game.with_lock do
        unless game.check_expired
          data[:notices].push({ type: "game_invite", info: game.json_info, sender: invite.sender.name,
            facebookId: invite.sender.facebook_id, message: invite.message })
        end
      end
    end
    render json: data
  end
  
  def last_turn
    game = Game.find(params[:id])
    game.with_lock do
      render json: create_game_notice(game)
    end
  end
  
  def resimulate
    @game = Game.find(params[:id])
  end
  
  def complete_tutorial
    @player.update(completed_tutorial: true)
    render plain: "success"
  end
  
  def game_invite_answer
    game_invite = @player.game_invites.find_by(game_id: params[:game_id])
    if game_invite
      if params[:accept] == "true"
        game = game_invite.game
        game.with_lock do
          if game.started?
            report_error "Sorry, game just filled up."
            game_invite.destroy
            return
          elsif game.players.exists? @player
            report_error "You've already joined that game."
            game_invite.destroy
            return
          else
            game.players << @player
          end
        end
      end
      game_invite.destroy
    end
    render plain: "success"
  end
  
  def move
    game_member = @player.game_members.find_by(game_id: params[:game_id])
    game = game_member.game
    game.with_lock do
      if params[:turn_number] && game.turn_number != params[:turn_number].to_i
        render plain: "Sorry, you missed the cutoff for that turn."
        return
      end
      game_member.update(move: params[:move])
    end
    render plain: "success"
  end
  
  def prompt_rankings
    order = :prompt_rating
    case params[:sort]
      when "answered"
        order = :prompts_answered
      when "won"
        order = :prompts_won
      when "votes"
        order = :votes_received
    end
    count = Player.where("prompts_answered > 0").count
    offset = RANKINGS_PER_PAGE * params[:page].to_i
    data = { rankings: [], continues: count > offset + RANKINGS_PER_PAGE }
    players = Player.where("prompts_answered > 0")
      .order(order => :desc)
      .limit(RANKINGS_PER_PAGE)
      .offset(offset)
    players.each do |player|
      ranking = { name: player.name, facebookId: player.facebook_id, rating: player.prompt_rating + RATING_OFFSET,
        answered: player.prompts_answered, won: player.prompts_won, votes: player.votes_received }
      data[:rankings].push ranking
    end
    render json: data
  end
  
  def game_rankings
    order = :rating
    case params[:sort]
      when "played"
        order = :games_played
      when "won"
        order = :games_won
    end
    count = Player.where("games_played > 0").count
    offset = RANKINGS_PER_PAGE * params[:page].to_i
    data = { rankings: [], continues: count > offset + RANKINGS_PER_PAGE }
    players = Player.where("games_played > 0")
      .order(order => :desc)
      .limit(RANKINGS_PER_PAGE)
      .offset(offset)
    players.each do |player|
      ranking = { name: player.name, facebookId: player.facebook_id, rating: player.rating + RATING_OFFSET,
        played: player.games_played, won: player.games_won }
      data[:rankings].push ranking
    end
    render json: data
  end
  
  def personal_stats
    stats = {
      gamesPlayed: @player.games_played,
      gamesPlayedRanking: Player.where("games_played > #{@player.games_played}").count + 1,
      gamesWon: @player.games_won,
      gamesWonRanking: Player.where("games_won > #{@player.games_won}").count + 1,
      promptsAnswered: @player.prompts_answered,
      promptsAnsweredRanking: Player.where("prompts_answered > #{@player.prompts_answered}").count + 1,
      promptsWon: @player.prompts_won,
      promptsWonRanking: Player.where("prompts_won > #{@player.prompts_won}").count + 1,
      votesReceived: @player.votes_received,
      votesReceivedRanking: Player.where("votes_received > #{@player.votes_received}").count + 1,
      rating: @player.rating + RATING_OFFSET,
      ratingRanking: Player.where("games_played > 0 and rating > #{@player.rating}").count + 1,
      promptRating: @player.prompt_rating + RATING_OFFSET,
      promptRatingRanking: Player.where("prompts_answered > 0 and prompt_rating > #{@player.prompt_rating}").count + 1 }
    render json: stats
  end
  
  private
    def open_game_count
      Game.where("start_time is not null").where(open_to_all: true).count
    end
  
    def get_published_tracks
      @published_tracks = Track.includes(:published_revision).where.not(published_revision_id: nil).order(:id)
    end
    
    def create_game_notice(game)
      member = game.game_members.find_by!(player_id: @player.id)
      notice = { type: "game_results", playerId: @player.id, gameId: game.id, trackRevision: game.track_revision_id,
        results: game.results, secret: member.secret, playerInfo: {}, gameInfo: game.json_info,
        secondsRemaining: game.next_next_move_time - Time.now }
      game.players.each do |player|
        notice[:playerInfo][player.id] = { name: player.name, facebookId: player.facebook_id }
      end
      notice
    end
    
    def configure_game
      state = params[:game]
      @game.title = Player.process_name(state[:title])
      @game.track_revision = TrackRevision.find(state[:track_revision])
      minmax = [ Game::MIN_MIN_PLAYERS, state[:min_players].to_i, state[:max_players].to_i, Game::MAX_MAX_PLAYERS ].sort
      @game.min_players = minmax[1]
      @game.max_players = minmax[2]
      case state[:open_to]
        when "all"
          @game.open_to_all = true
        when "all", "friends"
          @game.open_to_friends = true
      end
      @game.turn_interval = 24 * Game::MINUTES_PER_HOUR
      @game.moves_per_turn = Game::DEFAULT_MOVES_PER_TURN
      @game.move_distance = Game::DEFAULT_MOVE_DISTANCE
      @game.prompts_per_turn = Game::DEFAULT_PROMPTS_PER_TURN
      @game.start_time = @game.latest_move_time(Time.now + 48 * Game::MINUTES_PER_HOUR * Game::SECONDS_PER_MINUTE)
      if @player.admin
        @game.turn_interval = case state[:turn_interval]
          when "twice-daily"
            12 * Game::MINUTES_PER_HOUR
          else
            24 * Game::MINUTES_PER_HOUR
        end
        @game.early_turns = state[:early_turns] if state[:early_turns]
        @game.moves_per_turn = state[:moves_per_turn] if state[:moves_per_turn]
        @game.move_distance = state[:move_distance] if state[:move_distance]
        @game.prompts_per_turn = state[:prompts_per_turn] if state[:prompts_per_turn]
      end
      @game.save
    end
    
    def allow_iframe
      response.headers['X-Frame-Options'] = "ALLOW-FROM https://apps.facebook.com"
    end
end
