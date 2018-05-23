require_dependency "playfield"

class Game < ActiveRecord::Base
  
  # The overall minimum number of players.
  MIN_MIN_PLAYERS = 3
  
  # The overall maximum number of players.
  MAX_MAX_PLAYERS = 16
  
  # The default number of moves per turn.
  DEFAULT_MOVES_PER_TURN = 3
  
  # The default move distance.
  DEFAULT_MOVE_DISTANCE = 150
  
  # The default number of prompts per turn.
  DEFAULT_PROMPTS_PER_TURN = 3
  
  # The number of seconds in a minute.
  SECONDS_PER_MINUTE = 60
  
  # The number of minutes in an hour.
  MINUTES_PER_HOUR = 60
  
  # The time format to use in the JSON info.
  TIME_FORMAT = "%b %-d, %Y %I:%M %p %Z"
  
  # The proportional point at which we send email reminders of turns (three o'clock).
  TURN_REMINDER_POINT = 15.0 / 24.0
  
  # The exponent base used for Elo ratings.
  ELO_BASE = 10.0
  
  # The rating divisor used for Elo ratings.
  ELO_DIVISOR = 400.0
  
  # The K factor used for Elo ratings.
  ELO_K = 32.0
  
  belongs_to :track_revision
  has_many :game_members, dependent: :destroy
  has_many :players, through: :game_members
  has_many :game_invites, dependent: :destroy
  has_many :prompts, dependent: :destroy
  
  before_destroy :note_being_destroyed, prepend: true
  before_destroy :maybe_destroy_track_revision
  around_update :check_track_revision
  
  # Checks whether the game has started.
  def started?
    !self.start_time
  end
  
  # Returns the Javascript info for the game.
  def json_info
    info = { id: self.id, title: self.title, track: self.track_revision.name, minPlayers: self.min_players,
      maxPlayers: self.max_players, openToAll: self.open_to_all, openToFriends: self.open_to_friends,
      turnInterval: self.turn_interval, earlyTurns: !!self.early_turns, movesPerTurn: self.moves_per_turn,
      promptsPerTurn: self.prompts_per_turn, players: [],
      startTime: (self.start_time ? self.start_time.strftime(TIME_FORMAT) : nil),
      started: self.started?, turnNumber: self.turn_number,
      lastMoveTime: (self.last_move_time ? self.last_move_time.strftime(TIME_FORMAT) : nil) }
    self.players.each do |player|
      info[:players].push player.name
    end
    info
  end
  
  # Starts the game.
  def start
    # destroy all pending invites
    self.game_invites.clear
  
    results = {}
    results[:state] = []
    results[:prompts] = []
    results[:responses] = []
    
    playfield = Playfield.new
    playfield.json = JSON.parse(self.track_revision.data)
    starting_line = playfield.starting_lines.sample
    starting_line ||= LineSegment.new(Point.new(-100, 0), Point.new(100, 0))
    
    colors = Puck::COLORS.shuffle
    move_distances = Array.new(self.moves_per_turn, self.move_distance)
    secret = JSON.generate({ moveDistances: move_distances, actions: [ Boost.new.to_json ] })
    
    starting_line_length = starting_line.length
    pucks_per_row = [ ((starting_line_length - Puck::PADDING) / (Puck::RADIUS * 2.0 + Puck::PADDING)).floor,
      self.game_members.count ].min
    
    # compute the row vector
    rx = 0.0
    ry = 0.0
    if playfield.path.length >= 2
      rx = playfield.path[0][0].x - playfield.path[1][0].x
      ry = playfield.path[0][0].y - playfield.path[1][0].y
      scale = (Puck::RADIUS * 2.0 + Puck::PADDING * 0.5) / Math.hypot(rx, ry)
      rx *= scale
      ry *= scale
    end
    
    # and the column vector
    cx = starting_line.end_point.x - starting_line.start_point.x
    cy = starting_line.end_point.y - starting_line.start_point.y
    scale = 1.0 / starting_line_length
    cx *= scale
    cy *= scale
    
    # flip if wrong direction
    row_start = starting_line.start_point
    if rx * cy - ry * cx > 0.0
      row_start = starting_line.end_point
      cx = -cx
      cy = -cy
    end
    
    # arrange pucks in staggered rows at and behind starting line
    row_index = 0
    column_index = 0
    offset = (starting_line_length - (pucks_per_row - 1) * (Puck::RADIUS * 2.0 + Puck::PADDING)) / 2.0
    positions = []
    self.game_members.each do |game_member|
      distance = offset + (row_index % 2 == 0 ? 0 : Puck::RADIUS + 0.5 * Puck::PADDING) +
        column_index * (Puck::RADIUS * 2.0 + Puck::PADDING)
      positions.push Point.new(row_start.x + cx * distance, row_start.y + cy * distance)
      
      # advance to next column/row
      column_index += 1
      if column_index == (row_index % 2 == 0 ? pucks_per_row : pucks_per_row - 1)
        row_start = Point.new(row_start.x + rx, row_start.y + ry)
        row_index += 1
        column_index = 0
      end
    end
    positions.shuffle!
    
    self.game_members.each.with_index do |game_member, index|
      results[:state].push Puck.new(positions[index], colors[index], game_member.player_id).to_json
      game_member.update(secret: secret)
    end
    
    # turn prompt images into prompt features
    prompt_weights = get_prompt_weights
    playfield.prompt_images.each do |image|
      feature = image.dup
      feature.prompt = get_prompt(prompt_weights, image.role.chomp("-prompt"))
      results[:state].push feature.to_json
    end
    
    # generate initial set of prompts
    for index in 0...self.prompts_per_turn
      results[:prompts].push get_prompt(prompt_weights)
    end
    
    move_time = next_move_time
    update(results: JSON.generate(results), last_move_time: move_time, start_time: nil, turn_number: 1)
    TurnReminderJob.set(wait_until: move_time + (self.turn_interval *
      SECONDS_PER_MINUTE * (1.0 + TURN_REMINDER_POINT)).to_i).perform_later(self.id)
  end
  
  # Destroys the game if it has expired.
  def check_expired
    if !self.started? && Time.now >= self.start_time && self.game_members.count < self.min_players
      self.destroy
      return true
    end
    false
  end
  
  # Resimulates a turn for debugging.
  def resimulate(debug_player_id = 0)
    playfield = Playfield.new
    playfield.json = JSON.parse(self.track_revision.data)
    
    last_results = JSON.parse(self.results)
    
    pucks = []
    last_results["preState"].each do |json|
      feature = Feature.from_json(json)
      playfield.add_feature feature
      if feature.is_a? Puck
        pucks.push feature
        feature.move_distances = Array.new(self.moves_per_turn, self.move_distance)
        if feature.player_id == debug_player_id
          feature.debug = true
        end
      end
    end
    
    playfield.simulate(pucks)
  end
  
  # Executes a turn if appropriate.
  def maybe_execute_turn
    move_time = next_move_time
    if self.finished
      if self.last_move_time != move_time
        self.destroy
      end
      return false
    end
    
    if !self.started?
      return false if Time.now < self.start_time
      if self.game_members.count >= self.min_players
        self.start
        return true
      else
        self.destroy
        return false
      end
    end
    
    return false unless (self.last_move_time != move_time && any_members_moved) || (self.early_turns && all_members_moved)
    
    # get the last results and secret
    last_results = JSON.parse(self.results)
    last_secret = self.secret ? JSON.parse(self.secret) : { }
    
    # initialize the playfield with track data
    playfield = Playfield.new
    playfield.json = JSON.parse(self.track_revision.data)
    
    # initialize pucks from last state
    pucks_by_id = {}
    features = []
    pucks = []
    last_results["state"].each do |json|
      feature = Feature.from_json(json)
      if feature.is_a? Puck
        if self.game_members.exists?(player_id: feature.player_id)
          playfield.add_feature feature
          features.push feature
          pucks_by_id[feature.player_id] = feature
          pucks.push feature
        end
      else
        playfield.add_feature feature
        features.push feature
      end
    end
    
    # find the last prompts, responses, player ids; prepare for responses and voting
    last_prompts = last_results["prompts"]
    last_last_prompts = last_results["lastPrompts"]
    last_responses = last_results["responses"]
    if last_responses.length > 0 && last_responses[0].length == 1
      last_responses = [] # no need to vote; there was only one response
    end
    last_response_player_ids = last_secret["responsePlayerIds"]
    results = { lastPrompts: last_prompts, responsePlayerIds: [], lastLastPrompts: last_last_prompts,
      lastResponses: last_responses, lastResponsePlayerIds: last_response_player_ids }
    results[:responses] = last_prompts.collect { |prompt| [] }
    results[:votes] = last_responses.collect { |responses| Array.new(responses.length, 0) }
    
    # process each move, making sure that exceptions don't break the whole turn
    self.game_members.each do |game_member|
      if game_member.move
        begin
          # read moves and apply to puck, enforcing move distance limits
          member_move = JSON.parse(game_member.move)
          member_secret = JSON.parse(game_member.secret)
          moves = member_move["moves"].collect { |json| json.is_a?(Numeric) ? json.to_i : Point.from_json(json) }
          puck = pucks_by_id[game_member.player_id]
          puck.queue = []
          puck.move_distances = member_secret["moveDistances"]
          actions = member_secret["actions"].collect { |json| PuckAction.from_json(json) }
          
          # push the moves onto the queue
          moves.each do |move|
            if move.is_a? Point
              puck.queue.push move
            else
              action = actions[move]
              if action
                puck.queue.push action
                actions[move] = nil
              end  
            end
          end
          
          # read and store responses with player id
          responses = member_move["responses"]
          for index in 0...[last_prompts.length, responses.length].min
            response = Player.sanitize(responses[index][0...140])
            results[:responses][index].push({ player_id: game_member.player_id, response: response })
            Player.where(id: game_member.player_id).update_all("prompts_answered = prompts_answered + 1")
          end
          
          # read and count votes, making sure they're valid
          votes = member_move["votes"]
          for index in 0...[last_responses.length, votes.length].min
            vote = votes[index]
            if vote >= 0 && vote < last_responses[index].length &&
                vote != last_response_player_ids[index].index(game_member.player_id)
              results[:votes][index][vote] += 1
            end
          end
          
          # read and apply prompt ratings
          if last_last_prompts
            ratings = member_move["ratings"]
            for index in 0...[last_last_prompts.length, ratings.length].min
              rating = ratings[index]
              if rating == 1 || rating == -1
                prompt_type = Prompt.find(last_last_prompts[index]["id"]).prompt_type
                update_prompt_type_rating(game_member.player_id, prompt_type, rating)
                update_prompt_type_rating(0, prompt_type, rating)
              end
            end
          end
          
          rescue => detail
            puts detail.to_s + ": " + detail.backtrace.join("\n")
        end
      end
    end
    
    # store the pre-simulation state and simulate movement
    results[:preState] = features.collect { |feature| feature.to_json }
    playfield.simulate(pucks)
    
    # filter any removed features
    features.select! { |feature| feature.playfield }
    
    # compute and sort by progress
    highest_progress = 0.0
    pucks.each do |puck|
      if puck.finish_order
        puck.progress = 100.0 - puck.finish_order
      else
        puck.progress = playfield.get_progress(puck.translation)
        highest_progress = [ puck.progress, highest_progress ].max
      end
    end
    pucks.sort! { |a, b| b.progress <=> a.progress }
    
    # if this is the last move, finalize the finish orders and end
    if last_responses.empty? && last_prompts.empty?
      finish_order = 0
      pucks.each do |puck|
        puck.finish_order = finish_order
        finish_order += 1
      end
      
      update(finished: true)
    end
    
    # re-initialize move distances to default
    member_secrets = { }
    pucks.each do |puck|
      if puck.finish_order
        unless self.finishing
          update(finishing: true)
          rating_denominator = 0.0
          self.game_members.each do |game_member|
            player = Player.find(game_member.player_id)
            rating_denominator += ELO_BASE ** (player.rating / ELO_DIVISOR)
            Player.where(id: game_member.player_id).update_all("games_played = games_played + 1")
          end
          self.game_members.each do |game_member|
            player = Player.find(game_member.player_id)
            rating_numerator = ELO_BASE ** (player.rating / ELO_DIVISOR)
            score = (game_member.player_id == pucks[0].player_id ? 1 : 0)
            adjustment = (ELO_K * (score - rating_numerator / rating_denominator)).round
            if adjustment != 0
              Player.where(id: game_member.player_id).update_all("rating = rating + #{adjustment}")
            end
          end
          Player.where(id: pucks[0].player_id).update_all("games_won = games_won + 1")
        end
        puck.queue = []
        member_secrets[puck.player_id] = { moveDistances: [], actions: 0 }
      else
        member_secrets[puck.player_id] = { moveDistances: Array.new(self.moves_per_turn, self.move_distance),
          actions: 1 }
      end
    end
    
    # process (shuffle, anonymize) responses, handle immediate bonus when there's only one
    secret = { }
    secret[:responsePlayerIds] = last_prompts.collect { |prompt| [] }
    results[:responses].each.with_index do |responses, index|
      responses.shuffle!
      responses.collect! do |id_response|
        secret[:responsePlayerIds][index].push id_response[:player_id]
        id_response[:response]
      end
      if responses.length == 1
        player_id = secret[:responsePlayerIds][index][0]
        results[:responsePlayerIds].push player_id
        puck = pucks_by_id[player_id]
        member_secrets[player_id][:actions] += 1 unless puck.finish_order
      end
    end
    
    # process votes, granting bonus divided between recipients of max vote counts
    results[:votes].each.with_index do |votes, index|  
      # filter out the votes of anyone who left
      total_votes = 0.0
      rating_denominator = 0.0
      (0...votes.length).reverse_each do |vote_index|
        player_id = last_response_player_ids[index][vote_index]
        if pucks_by_id[player_id]
          player = Player.find(player_id)
          rating_denominator += ELO_BASE ** (player.prompt_rating / ELO_DIVISOR)
          vote_count = votes[vote_index]
          if vote_count > 0
            Player.where(id: player_id).update_all("votes_received = votes_received + #{vote_count}")
            total_votes += vote_count
          end
        else
          votes.delete_at vote_index
          last_response_player_ids[index].delete_at vote_index
          last_responses[index].delete_at vote_index
        end
      end
      
      # find the max number of votes and, if non-zero, bestow the bonus
      max_votes = votes.max
      if max_votes > 0
        votes.each.with_index do |vote_count, vote_index|
          player_id = last_response_player_ids[index][vote_index]
          player = Player.find(player_id)
          rating_numerator = ELO_BASE ** (player.prompt_rating / ELO_DIVISOR)
          score = vote_count / total_votes
          adjustment = (ELO_K * (score - rating_numerator / rating_denominator)).round
          if adjustment != 0
            Player.where(id: player_id).update_all("prompt_rating = prompt_rating + #{adjustment}")
          end
          if vote_count == max_votes
            puck = pucks_by_id[player_id]
            Player.where(id: player_id).update_all("prompts_won = prompts_won + 1")
            member_secrets[player_id][:actions] += 1 unless puck.finish_order
          end
        end
      end
    end
    
    # assign the desired number of actions depending on progress
    path_length = playfield.path_length
    pucks.each do |puck|
      count = member_secrets[puck.player_id][:actions]
      member_secrets[puck.player_id][:actions] = []
      if count > 0
        desired_length = (highest_progress - puck.progress) * path_length / count
        for index in 0...count
          member_secrets[puck.player_id][:actions].push(get_action(desired_length).to_json)
        end
      end
    end
    
    # update the member secrets and clear moves
    self.game_members.each do |game_member|
      member_secret = member_secrets[game_member.player_id]
      member_secret[:responseIndices] = secret[:responsePlayerIds].collect {
        |playerIds| playerIds.index(game_member.player_id) }
      game_member.update(move: nil, secret: JSON.generate(member_secret))
    end
    
    # collect the post-move state
    results[:state] = features.collect { |feature| feature.to_json }
    
    # add the next set of prompts unless the game is ending
    prompt_weights = get_prompt_weights
    results[:prompts] = []
    unless self.finishing
      for index in 0...self.prompts_per_turn
        results[:prompts].push(index < playfield.collided_prompts.length ?
          playfield.collided_prompts[index] : get_prompt(prompt_weights))
      end
    end
    
    update(results: JSON.generate(results), secret: JSON.generate(secret),
      last_move_time: move_time, turn_number: turn_number + 1)
    unless self.finished
      TurnReminderJob.set(wait_until: move_time + (self.turn_interval *
        SECONDS_PER_MINUTE * (1.0 + TURN_REMINDER_POINT)).to_i).perform_later(self.id)
    end
    true
  end
  
  # Checks whether the game is currently being destroyed.
  def being_destroyed?
    @being_destroyed
  end
  
  # Returns the latest move time before the time specified.
  def latest_move_time(time)
    interval = self.turn_interval * SECONDS_PER_MINUTE
    midnight = time.midnight.to_i
    elapsed = time.to_i - midnight
    Time.at(midnight + interval * (elapsed / interval))
  end
  
  def next_move_time
    self.latest_move_time(Time.now)
  end
  
  def next_next_move_time
    self.latest_move_time(Time.now + turn_interval.minute)
  end
    
  private
    def note_being_destroyed
      @being_destroyed = true
    end
  
    def maybe_destroy_track_revision
      old_revision_id = self.track_revision_id.to_i
      self.update(track_revision_id: nil)
      TrackRevision.find(old_revision_id).maybe_destroy
    end
    
    def check_track_revision
      old_revision_id = self.track_revision_id.to_i
      yield
      new_revision_id = self.track_revision_id.to_i
      unless old_revision_id == new_revision_id
        TrackRevision.find(old_revision_id).maybe_destroy
      end
    end
        
    def any_members_moved
      self.game_members.each do |game_member|
        return true if game_member.move
      end
      false
    end
    
    def all_members_moved
      self.game_members.each do |game_member|
        return false unless game_member.move
      end
      true
    end
    
    def get_weighted(pairs)
      total_weight = pairs.reduce(0.0) { |sum, pair| sum + pair[1] }
      target = rand() * total_weight
      pairs.each do |pair|
        target -= pair[1]
        if target <= 0.0
          return pair[0]
        end
      end
    end
    
    MIN_ACTION_WEIGHT = 1.0
    PEAK_ACTION_WEIGHT = 5.0
    MAX_ACTION_WEIGHT = 6.0
    
    def get_action(desired_length)
      base_length = self.move_distance
      actions = [ Boost.new, Extra.new(base_length), Split.new, Pause.new ]
      action_weights = actions.map { |action| [ action, action.get_expected_length(base_length) ] }
      min_action_weight, max_action_weight = action_weights.minmax_by { |action_weight| action_weight[1] }
      min_expected_length, max_expected_length = min_action_weight[1], max_action_weight[1]
      contrast = PEAK_ACTION_WEIGHT * 2.0 / (max_expected_length - min_expected_length)
      action_weights.each do |action_weight|
        if action_weight[1] == min_expected_length
          action_weight[1] = PEAK_ACTION_WEIGHT + (min_expected_length - desired_length) * contrast
        elsif action_weight[1] == max_expected_length
          action_weight[1] = PEAK_ACTION_WEIGHT + (desired_length - max_expected_length) * contrast
        else
          action_weight[1] = PEAK_ACTION_WEIGHT - (action_weight[1] - desired_length).abs * contrast
        end
        action_weight[1] = [ MIN_ACTION_WEIGHT, action_weight[1], MAX_ACTION_WEIGHT ].sort![1]
      end
      get_weighted(action_weights)
    end
    
    def update_prompt_type_rating(player_id, prompt_type, rating)
      condition = PromptTypeRating.where(player_id: player_id, prompt_type: prompt_type)
      unless condition.exists?
        begin
          condition.create(value: 0, total: 0)
        rescue ActiveRecord::RecordNotUnique
          # ignore; someone got there first
        end
      end
      condition.update_all("value = value + #{rating}, total = total + 1")
    end
    
    PROMPT_WEIGHT_BASE = 3.0
    
    def get_prompt_weights
      global_ratings = get_prompt_type_ratings(0)
      combined_ratings = { }
      self.game_members.each do |game_member|
        member_ratings = get_prompt_type_ratings(game_member.player_id)
        global_ratings.each do |key, value|
          rating = value[0]
          member_rating = member_ratings[key]
          if member_rating
            rating = member_rating[0] + (rating - member_rating[0]) / (member_rating[1] + 1)
          end
          combined = combined_ratings[key]
          if combined
            combined[0] += rating
            combined[1] += 1
          else
            combined_ratings[key] = [ rating, 1 ]
          end
        end
      end
      weights = []
      Prompt::TYPES.each do |type|
        value = 0.0
        combined_rating = combined_ratings[type.name]
        if combined_rating
          value = combined_rating[0] / combined_rating[1]
        end
        weights.append [ type.name, PROMPT_WEIGHT_BASE ** value ]
      end
      weights
    end
    
    def get_prompt_type_ratings(player_id)
      highest_positive = 0
      lowest_negative = 0
      type_ratings = {}
      PromptTypeRating.where(player_id: player_id).each do |rating|
        highest_positive = [ highest_positive, rating.value ].max
        lowest_negative = [ lowest_negative, rating.value ].min
        type_ratings[rating.prompt_type] = [ rating.value, rating.total ]
      end
      type_ratings.each do |key, value|
        value[0] = value[0].to_f / (value[0] > 0 ? highest_positive : -lowest_negative)
      end
      type_ratings
    end
    
    def get_prompt(weights, type = nil)
      unless type
        return get_prompt(weights, get_weighted(weights))
      end
      prompt = nil
      while !prompt
        open_prompts = Prompt.where(prompt_type: type, game_id: nil)
        prompt = open_prompts.offset(rand(open_prompts.count)).first
        if prompt
          prompt.with_lock do
            if prompt.url_valid?
              begin
                prompt.reload
                if prompt.game_id
                  prompt = nil
                else
                  prompt.update game_id: self.id    
                end
              rescue ActiveRecord::RecordNotFound
                prompt = nil
              end
            else
              prompt.destroy
              prompt = nil
            end
          end
        else
          prompt = Prompt.generate type, self.id
          if !prompt
            return get_prompt(weights)
          end
        end
      end
      { id: prompt.id, inlineUrl: prompt.inline_url, fullUrl: prompt.full_url }
    end
end
