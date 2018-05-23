# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

root = exports ? this

# The top-level game canvas class.
class GameCanvas
  constructor: ->
    if !document.cookie && navigator.userAgent.indexOf("Safari") != -1 && navigator.userAgent.indexOf("Chrome") == -1
      window.top.location.replace $("#canvas").attr("fb-login-redirect-url")
      return
    @playfield = new Playfield
    @tutorial = new Tutorial(@playfield, this)
    @facebook = ($("#canvas").attr("facebook") == "true")
    @facebookEmail = ($("#canvas").attr("facebook-email") == "true")
    updateLayerSizes = =>
      playfield = $("#playfield").get(0)
      @playfield.base.canvas.width = playfield.clientWidth
      @playfield.base.canvas.height = playfield.clientHeight
      @playfield.base.dirty()
      @playfield.overlay.canvas.width = playfield.clientWidth
      @playfield.overlay.canvas.height = playfield.clientHeight
      @playfield.overlay.dirty()
    $(window).resize => # preserve center when resizing
      cx = @playfield.base.translation.x + Math.round(@playfield.base.canvas.width / 2)
      cy = @playfield.base.translation.y + Math.round(@playfield.base.canvas.height / 2)
      updateLayerSizes()
      @playfield.setTranslation(new Point(cx - Math.round(@playfield.base.canvas.width / 2),
        cy - Math.round(@playfield.base.canvas.height / 2)))
    updateLayerSizes()
    $("#playfield").on "touchmove", (event) -> event.preventDefault()
    @setupLogin()
    @setupCreateAccount()
    @setupForgotPassword()
    @setupChangePassword()
    @setupSetName()
    @setupMainMenu()
    @setupJoinedGames()
    @setupOpenGames()
    @setupNewGame()
    @setupRankings()
    @setupInvitePlayer()
    @setupPreferences()
    @pushAvailable = false
    @pushEnabled = false
    if navigator.serviceWorker?
      navigator.serviceWorker.register("/service-worker.js").then =>
        return unless ServiceWorkerRegistration.prototype.showNotification? &&
          Notification.permission != "denied" && window.PushManager?
        @pushAvailable = true
        navigator.serviceWorker.ready.then (serviceWorkerRegistration) =>
          serviceWorkerRegistration.pushManager.getSubscription().then (subscription) =>
            @pushEnabled = subscription?
            @setPushEndpoint(if @pushEnabled then subscription.endpoint else null)
    $.ajaxSetup { cache: true }
    if $("#canvas").attr("logged-in") == "true" && !@facebook
      if $("#canvas").attr("name-set") != "true" 
        $("#set-name").modal()
      else if $("#canvas").attr("change-password") == "true"  
        $("#change-password").one "hidden.bs.modal", => @fetchNotices()
        $("#change-password").modal()
      else
        @fetchNotices()
      return
    $("#loading").modal()
    $(".fb-login-button").attr("onlogin", "checkLoginStatus()")
    $.getScript "//connect.facebook.net/en_US/sdk.js", =>
      FB.init { xfbml: 1, appId: $("#fb-root").attr("app-id"), version: "v2.3" }
      if @facebook && @facebookEmail
        @fetchNotices()
        return
      callback = (response) =>
        if response.status == "connected"
          @facebook = true
          $("#login").modal("hide")
          $("#loading").modal()
          FB.api "/me/permissions", (permissions) =>
            email = false
            if permissions? && permissions.data?
              for datum in permissions.data
                if datum.permission == "email" && datum.status == "granted"
                  email = true
                  break
            unless email || $("#canvas").attr("canvas") != "true"
              FB.login(callback, { scope: "public_profile,email,user_friends" })
              return
            data = {
              "credentials[fb_token]": response.authResponse.accessToken
              "credentials[stay_logged_in]": (if $("#login #remember-me").get(0).checked then "1" else "0")
            }
            $.post $("#canvas").attr("login-path"), data, (data, status) =>
              @fetchNotices() if status == "success"
        else if $("#canvas").attr("canvas") != "true"
          $("#loading").modal("hide")
          $("#login").modal()
        else
          FB.login(callback, { scope: "public_profile,email,user_friends" })
      root.checkLoginStatus = -> FB.getLoginStatus callback
      if $("#canvas").attr("canvas") == "true"
        if @facebook && !@facebookEmail
          FB.login(callback, { scope: "public_profile,email,user_friends" })
        else  
          checkLoginStatus()
      else
        $("#loading").modal("hide")
        $("#login").modal()
  
  # Sets the push endpoint on the server.
  setPushEndpoint: (endpoint) ->
    $.post $("#canvas").attr("push-endpoint-path"), { endpoint: endpoint }
    
  # Wires up the login dialog.
  setupLogin: ->
    fieldListener = ->
      $("#login #login-button").get(0).disabled = ($("#login #email").val().length == 0 ||
        $("#login #password").val().length == 0)
    $("#login #email").on "input", fieldListener
    $("#login #password").on "input", fieldListener
    fieldListener()
    $("#login #login-button").click (event) =>
      $("#login button").attr "disabled", "disabled"
      @showAlertPending("login")
      data = {
        "credentials[email]": $("#login #email").val()
        "credentials[password]": $("#login #password").val()
        "credentials[stay_logged_in]": (if $("#login #remember-me").get(0).checked then "1" else "0")
      }
      $.post $("#canvas").attr("login-path"), data, (data, status) =>
        $("#login button").removeAttr "disabled"
        @clearAlertPending("login")
        fieldListener()
        if status == "success" && data == "success"
          $("#login").modal("hide")
          @fetchNotices()
        else
          @showAlert("login", (if status == "success" then data else status))
    $("#login #create-account-button").click =>
      $("#login").modal("hide")    
      $("#create-account").modal()  
    $("#login #forgot-password-button").click =>
      $("#login").modal("hide")
      $("#forgot-password").modal()
      
  # Wires up the create account dialog.
  setupCreateAccount: ->
    fieldListener = ->
      $("#create-account #create-account-button").get(0).disabled = ($("#create-account #name").val().length == 0 ||
        $("#create-account #email").val().length == 0 || $("#create-account #password").val().length == 0 ||
        $("#create-account #confirm-password").val().length == 0)
    $("#create-account #name").on "input", fieldListener
    $("#create-account #email").on "input", fieldListener
    $("#create-account #password").on "input", fieldListener
    $("#create-account #confirm-password").on "input", fieldListener
    fieldListener()
    $("#create-account #create-account-button").click (event) =>
      $("#create-account button").attr "disabled", "disabled"
      @showAlertPending("create-account")
      data = {
        "player[name]": $("#create-account #name").val()
        "player[email]": $("#create-account #email").val()
        "player[password]": $("#create-account #password").val()
        "player[password_confirmation]": $("#create-account #confirm-password").val()
      }
      $.post $("#canvas").attr("players-path"), data, (data, status) =>
        @clearAlertPending("create-account")
        fieldListener()
        if status == "success" && data == "success"
          @showAlert("create-account", "Confirmation email sent.", "success")
        else
          $("#create-account button").removeAttr "disabled"
          @showAlert("create-account", (if status == "success" then data else status))
    $("#create-account #login-button").click (event) =>
      $("#create-account").modal("hide")
      $("#login").modal()
  
  # Wires up the forgot password dialog.
  setupForgotPassword: ->
    fieldListener = ->
      $("#forgot-password #send-reset-email").get(0).disabled = ($("#forgot-password #email").val().length == 0)
    $("#forgot-password #email").on "input", fieldListener
    fieldListener()
    $("#forgot-password #send-reset-email").click (event) =>
      $("#forgot-password button").attr "disabled", "disabled"
      @showAlertPending("forgot-password")
      data = { "reset[email]": $("#forgot-password #email").val() }
      $.post $("#canvas").attr("password-reset-path"), data, (data, status) =>
        $("#forgot-password button").removeAttr "disabled"
        @clearAlertPending("forgot-password")
        fieldListener()
        if status == "success" && data == "success"
          @showAlert("forgot-password", "If that address was registered, a reset email was sent.", "success")
        else
          @showAlert("forgot-password", (if status == "success" then data else status))
    $("#forgot-password #login-button").click (event) =>
      $("#forgot-password").modal("hide")
      $("#login").modal()
  
  # Sets up the password change dialog.
  setupChangePassword: ->
    fieldListener = ->
      $("#change-password #change-password-button").get(0).disabled = ($("#change-password #password").val().length == 0 ||
        $("#change-password #confirm-password").val().length == 0)
    $("#change-password #password").on "input", fieldListener
    $("#change-password #confirm-password").on "input", fieldListener
    fieldListener()
    $("#change-password #change-password-button").click (event) =>
      $("#change-password button").attr "disabled", "disabled"
      @showAlertPending("change-password")
      data = {
        "player[password]": $("#change-password #password").val()
        "player[password_confirmation]": $("#change-password #confirm-password").val()
      }
      $.post $("#canvas").attr("change-password-path"), data, (data, status) =>
        $("#change-password button").removeAttr "disabled"
        @clearAlertPending("change-password")
        fieldListener()
        if status == "success" && data == "success"
          $("#change-password").modal("hide")
        else
          @showAlert("change-password", (if status == "success" then data else status))
        
  # Sets up the name set dialog.
  setupSetName: ->
    fieldListener = ->
      $("#set-name #set-name-button").get(0).disabled = ($("#set-name #name").val().length == 0 ||
        $("#set-name #password").val().length == 0 || $("#set-name #confirm-password").val().length == 0)
    $("#set-name #name").on "input", fieldListener
    $("#set-name #password").on "input", fieldListener
    $("#set-name #confirm-password").on "input", fieldListener
    fieldListener()
    $("#set-name #set-name-button").click (event) =>
      $("#set-name button").attr "disabled", "disabled"
      @showAlertPending("set-name")
      data = {
        "player[name]": $("#set-name #name").val()
        "player[password]": $("#set-name #password").val()
        "player[password_confirmation]": $("#set-name #confirm-password").val()
      }
      $.post $("#canvas").attr("set-name-path"), data, (data, status) =>
        $("#set-name button").removeAttr "disabled"
        @clearAlertPending("set-name")
        fieldListener()
        if status == "success" && data == "success"
          $("#set-name").modal("hide")
          @fetchNotices()
        else
          @showAlert("set-name", (if status == "success" then data else status))
  
  # Sets up the main menu dialog.
  setupMainMenu: ->
    $("#main-menu #show-joined-games").click (event) =>
      $("#main-menu").modal("hide")
      @displayJoinedGames()
    $("#main-menu #find-open-games").click (event) =>
      $("#main-menu").modal("hide")
      @displayOpenGames()
    $("#main-menu #create-new-game").click (event) =>
      $("#main-menu").modal("hide")
      @displayNewGame()
    $("#main-menu #view-rankings").click (event) =>
      $("#main-menu").modal("hide")
      @displayRankings()
    $("#main-menu #check-notices").click (event) =>
      $("#main-menu").modal("hide")
      @fetchNotices()
    $("#main-menu #tutorial").click (event) =>
      $("#main-menu").modal("hide")
      @tutorial.display => @fetchNotices()
    $("#main-menu #set-preferences").click (event) =>
      $("#main-menu").modal("hide")
      @displayPreferences()
    if $("#canvas").attr("canvas") == "true"
      $("#main-menu #logout").css "display", "none"
    else
      $("#main-menu #logout").click (event) =>
        $("#main-menu").modal("hide")
        $("#loading").modal()
        $.post $("#canvas").attr("logout-path"), (data, status) =>
          window.open("/", "_self")
  
  # Sets up the joined games dialog.
  setupJoinedGames: ->
    $("#joined-games #back-to-main").click (event) =>
      $("#joined-games").modal("hide")
      @fetchNotices()
      
  # Sets up the open games dialog.
  setupOpenGames: ->
    $("#open-games #back").click (event) =>
      @displayOpenGamePage(@openGamePage - 1)
    $("#open-games #next").click (event) =>
      @displayOpenGamePage(@openGamePage + 1)
    $("#open-games #back-to-main").click (event) =>
      $("#open-games").modal("hide")
      @fetchNotices()
      
  # Sets up the new game dialog.
  setupNewGame: ->
    $("#new-game #create").click (event) =>
      $("#new-game button").attr "disabled", "disabled"
      @showAlertPending("new-game")
      data = {
        "game[title]": $("#new-game #title").val()
        "game[track_revision]": $("#new-game #track").val()
        "game[min_players]": $("#new-game #minimum-players").val()
        "game[max_players]": $("#new-game #maximum-players").val()
        "game[open_to]": $("#new-game #open-to").val()
      }
      $.post $("#canvas").attr("games-path"), data, (data, status) =>
        $("#new-game button").removeAttr "disabled"
        @clearAlertPending("new-game")
        if status == "success" && data == "success"
          $("#new-game").modal("hide")
          @displayJoinedGames()
        else
          @showAlert("new-game", (if status == "success" then data else status))
    $("#new-game #back-to-main").click (event) =>
      $("#new-game").modal("hide")
      @fetchNotices()
 
  # Sets up the rankings dialog.
  setupRankings: ->
    $("#rankings #prompts").click (event) =>
      @selectRankingsTab("prompts")
    $("#rankings #games").click (event) =>
      @selectRankingsTab("games")
    $("#rankings #personal-stats").click (event) =>
      @selectRankingsTab("personal-stats")
    $("#rankings #back-to-main").click (event) =>
      $("#rankings").modal("hide")
      @fetchNotices()
 
  @RANKINGS_TABS: [ "prompts", "games", "personal-stats" ]
 
  # Selects a tab in the rankings dialog.
  selectRankingsTab: (selected) ->
    for tab in GameCanvas.RANKINGS_TABS
      if tab == selected
        $("#rankings ##{tab}-tab").addClass "active"
      else
        $("#rankings ##{tab}-tab").removeClass "active"
    $("#rankings ##{selected}").blur()
    switch selected
      when "prompts"
        @displayPromptRankings()
      when "games"
        @displayGameRankings()
      when "personal-stats"
        @showAlertPending("rankings")
        $("#rankings #back").css "display", "none"
        $("#rankings #next").css "display", "none"
        $("#rankings button").attr "disabled", "disabled"
        $.get $("#canvas").attr("personal-stats-path"), (data, status) =>
          @clearAlertPending("rankings")
          $("#rankings button").removeAttr "disabled"
          $("#rankings #content").html "<div class='panel panel-default'>" +
            "<div class='panel-heading'>Prompt Rankings</div>" +
            "<div class='panel-body'>" +
            "Rating: #{data.promptRating} (##{data.promptRatingRanking})<br>" +
            "Answered: #{data.promptsAnswered} (##{data.promptsAnsweredRanking})<br>" +
            "Won: #{data.promptsWon} (##{data.promptsWonRanking})<br>" +
            "Votes: #{data.votesReceived} (##{data.votesReceivedRanking})</div></div>" +
            "<div class='panel panel-default'>" +
            "<div class='panel-heading'>Game Rankings</div>" +
            "<div class='panel-body'>" +
            "Rating: #{data.rating} (##{data.ratingRanking})<br>" +
            "Played: #{data.gamesPlayed} (##{data.gamesPlayedRanking})<br>" +
            "Won: #{data.gamesWon} (##{data.gamesWonRanking})</div></div>"
  
  # Displays the specified page of the prompt rankings.
  displayPromptRankings: (page = 0, sort = "rating") ->
    @showAlertPending("rankings")
    $("#rankings #back").css "display", "inline"
    $("#rankings #next").css "display", "inline"
    $("#rankings button").attr "disabled", "disabled"
    $.get $("#canvas").attr("prompt-rankings-path"), { page: page, sort: sort }, (data, status) =>
      @clearAlertPending("rankings")
      $("#rankings button").removeAttr "disabled"
      if page == 0
        $("#rankings #back").attr("disabled", "disabled")
      else
        $("#rankings #back").get(0).onclick = => @displayPromptRankings(page - 1, sort)
      if data.continues
        $("#rankings #next").get(0).onclick = => @displayPromptRankings(page + 1, sort)
      else  
        $("#rankings #next").attr("disabled", "disabled")
      rows = ""
      for ranking in data.rankings
        name = "#{ranking.name}"
        if ranking.facebookId?
          name = "<a href='https://facebook.com/#{ranking.facebookId}' target='_blank'>#{name}</a>"
        rows += "<tr><td>#{name}</td><td>#{ranking.rating}</td>" +
          "<td>#{ranking.answered}</td><td>#{ranking.won}</td><td>#{ranking.votes}</td></tr>"
      $("#rankings #content").html "<table class='table table-bordered table-striped'>" +
        "<tr><th>Name</th><th><a id='rating' href='#'>Rating</a></th><th><a id='answered' href='#'>Answered</a></th>" +
        "<th><a id='won' href='#'>Won</a></th><th><a id='votes' href='#'>Votes</a></th></tr>" +
        rows + 
        "</table>"
      for order in [ "rating", "answered", "won", "votes" ]
        do (order) =>
          $("#rankings ##{order}").get(0).onclick = => @displayPromptRankings(0, order)
      
  # Displays the specified page of the game rankings.
  displayGameRankings: (page = 0, sort = "rating") ->
    @showAlertPending("rankings")
    $("#rankings #back").css "display", "inline"
    $("#rankings #next").css "display", "inline"
    $("#rankings button").attr "disabled", "disabled"
    $.get $("#canvas").attr("game-rankings-path"), { page: page, sort: sort }, (data, status) =>
      @clearAlertPending("rankings")
      $("#rankings button").removeAttr "disabled"
      if page == 0
        $("#rankings #back").attr("disabled", "disabled")
      else
        $("#rankings #back").get(0).onclick = => @displayGameRankings(page - 1, sort)
      if data.continues
        $("#rankings #next").get(0).onclick = => @displayGameRankings(page + 1, sort)
      else  
        $("#rankings #next").attr("disabled", "disabled")
      rows = ""
      for ranking in data.rankings
        name = "#{ranking.name}"
        if ranking.facebookId?
          name = "<a href='https://facebook.com/#{ranking.facebookId}' target='_blank'>#{name}</a>"
        rows += "<tr><td>#{name}</td><td>#{ranking.rating}</td><td>#{ranking.played}</td><td>#{ranking.won}</td></tr>"
      $("#rankings #content").html "<table class='table table-bordered table-striped'>" +
        "<tr><th>Name</th><th><a id='rating' href='#'>Rating</a></th><th>" +
        "<a id='played' href='#'>Played</a></th><th><a id='won' href='#'>Won</a></th></tr>" +
        rows + 
        "</table>"
      for order in [ "rating", "played", "won" ]
        do (order) =>
          $("#rankings ##{order}").get(0).onclick = => @displayGameRankings(0, order)
      
  # Sets up the invite player dialog.
  setupInvitePlayer: ->
    sendInvite = (data) =>
      $("#invite-player button").attr "disabled", "disabled"
      @showAlertPending("invite-player")
      $.post $("#canvas").attr("game-invites-path").replace("0", @gameId), data, (data, status) =>
        $("#invite-player button").removeAttr "disabled"
        @clearAlertPending("invite-player")
        if status == "success" && data == "success"
          @showAlert("invite-player", "Invitation sent.")
        else
          @showAlert("invite-player", (if status == "success" then data else status))
    $("#invite-player #facebook-invite").click (event) =>
      fbMessage = "I've invited you to play a game!"
      message = $("#invite-player #message").val()
      if message != ""
        fbMessage += " '#{message}'"
      FB.ui { method: "apprequests", message: fbMessage }, (response) =>
        return unless response.to?
        sendInvite {
          "game_invite[fb_response]": JSON.stringify(response)
          "game_invite[message]": message
        }          
    $("#invite-player #send-invite").click (event) =>
      sendInvite {
        "game_invite[name]": $("#invite-player #name").val()
        "game_invite[email]": $("#invite-player #email").val()
        "game_invite[message]": $("#invite-player #message").val()
      }
    $("#invite-player #back-to-joined").click (event) =>
      $("#invite-player").modal("hide")
      @displayJoinedGames()
  
  # Sets up the preferences dialog.
  setupPreferences: ->
    $("#preferences #ok").click (event) =>
      $("#preferences button").attr "disabled", "disabled"
      @showAlertPending("preferences")
      data = {
        emailNotifications: $("#preferences #email-notifications").get(0).checked
      }
      $.post $("#canvas").attr("preferences-path"), data, (data, status) =>
        $("#preferences button").removeAttr "disabled"
        @clearAlertPending("preferences")
        $("#preferences").modal("hide")
        @fetchNotices()
      return if @pushEnabled == $("#preferences #push-notifications").get(0).checked
      if @pushEnabled
        navigator.serviceWorker.ready.then (serviceWorkerRegistration) =>
          serviceWorkerRegistration.pushManager.getSubscription().then (subscription) =>
            unless subscription?
              @pushEnabled = false
              @setPushEndpoint(null)
              return
            subscription.unsubscribe().then =>
              @pushEnabled = false
              @setPushEndpoint(null)
      else
        navigator.serviceWorker.ready.then (serviceWorkerRegistration) =>
          serviceWorkerRegistration.pushManager.subscribe({userVisibleOnly: true}).then (subscription) =>
            @pushEnabled = true
            @setPushEndpoint(subscription.endpoint)
    $("#preferences #cancel").click (event) =>
      $("#preferences").modal("hide")
      @fetchNotices()
      
  # Shows that an alert is forthcoming.
  showAlertPending: (dialog) ->
    $("##{dialog} #alert-container").html "<div class='centered'><img src='/assets/loading.gif'></div>"
  
  # Clears the pending alert notification.
  clearAlertPending: (dialog) ->
    $("##{dialog} #alert-container").html ""
  
  # Shows an alert with the specified level and message in the given dialog.
  showAlert: (dialog, message, level = "danger", closable = true) ->
    button = ""
    if closable
      button = "<button class='close' data-dismiss='alert'>&times;</button>"
    $("##{dialog} #alert-container").html "<div class='alert alert-#{level}'>" +
      "#{button}#{message}</div>"
  
  # Retrieves the notices from the server.
  fetchNotices: ->
    $("#loading").modal()
    $.get $("#canvas").attr("notices-path"), (data, status) =>
      $("#loading").modal("hide")
      if status == "success"
        @playerName = data.playerName
        if @facebook
          @playerName = @playerName.split(" ", 1)[0]
        @joinedGames = data.joinedGames
        @openGames = data.openGames
        @setNotices(data.notices)
      else
        @displayMainMenu()
  
  # Sets the notices to display.
  setNotices: (notices) ->
    @notices = notices
    if @notices.length > 0 then @displayNextNotice() else @displayMainMenu()
  
  # Displays the main menu.
  displayMainMenu: ->
    $("#main-menu #welcome").html "Welcome, #{@playerName}!<br><br>"
    $("#main-menu #joined-game-count").html (if @joinedGames > 0 then " (#{@joinedGames})" else "")
    $("#main-menu #open-game-count").html (if @openGames > 0 then " (#{@openGames})" else "")
    $("#main-menu").modal()
  
  # Displays the joined games dialog.
  displayJoinedGames: ->
    $("#loading").modal()
    $.get $("#canvas").attr("joined-games-path"), (data, status) =>
      $("#loading").modal("hide")
      $("#joined-games .panel-group").html ""
      data.sort (a, b) ->
        if a.started && !b.started
          return 1
        if b.started && !a.started
          return -1
        b.id - a.id
      for info in data
        $("#joined-games .panel-group").append @createGameInfoElement(info)
      $("#joined-games").modal()
  
  # Creates and returns a game info element.
  createGameInfoElement: (info, joined = true, joinable = true, leavable = true, source = "joined-games") ->
    element = document.createElement "div"
    element.className = "panel panel-default"
    startString = ""
    if info.started
      startString = "Turn ##{info.turnNumber}, last at #{info.lastMoveTime}"
    else
      startString = "#{info.minPlayers}-#{info.maxPlayers} players, " +
        "#{if info.openToAll then "open to all" else "invite only"}, starts at #{info.startTime}"
    buttons = ""
    if joined
      if info.started
        buttons += "<button id='replay-last' class='btn btn-success'>Replay Last Turn</button>" if leavable
      else
        buttons += "<button id='invite' class='btn btn-success'>Invite</button>"
      buttons += " &nbsp<button id='leave' class='btn btn-success'>Leave</button>" if leavable
    else if joinable
      buttons = "<button id='join' class='btn btn-success'>Join</button>"
    element.innerHTML =
      (if info.title == "" then "" else "<div class='panel-heading'>'#{info.title}'</div>") +
      "<div class='panel-body'>" +
      "Track: #{info.track}<br>" +
      "#{@getIntervalString(info.turnInterval)} turn interval, " +
      (if info.earlyTurns then "early turns allowed, " else "") +
      "#{info.movesPerTurn} base moves/turn, #{info.promptsPerTurn} prompts/turn<br>" +
      "#{startString}<br>" +
      "Players: #{info.players.join(', ')}<br>" +
      "<span class='pull-right'>#{buttons}</span>" +
      "</div>"
    $(element).find("#replay-last").click =>
      $("##{source}").modal("hide")
      $("#loading").modal()
      $.get $("#canvas").attr("last-turn-path").replace("0", info.id), (data, status) =>
        @displayGameResults(data.playerId, data.gameId, data.trackRevision, data.results,
          data.secret, data.playerInfo, data.gameInfo, data.secondsRemaining, true)
    $(element).find("#invite").click =>
      $("##{source}").modal("hide")
      @displayInvitePlayer(info.id)
    $(element).find("#leave").click =>
      return unless confirm "Are you sure you want to leave this game?"
      $("##{source}").modal("hide")
      $("#loading").modal()
      $.post $("#canvas").attr("leave-game-path").replace("0", info.id), (data, status) =>  
        @displayJoinedGames()
    $(element).find("#join").click =>
      $("##{source}").attr "disabled", "disabled"
      @showAlertPending("open-games")
      $.post $("#canvas").attr("join-game-path").replace("0", info.id), (data, status) =>  
        $("#open-games button").removeAttr "disabled"
        @clearAlertPending("open-games")
        if status == "success" && data == "success"
          $("#open-games").modal("hide")
          @displayJoinedGames()
        else
          @showAlert("open-games", (if status == "success" then data else status))
    element
  
  # Returns a string to describe the specified minute interval.
  getIntervalString: (interval) ->
    number = Number(interval)
    return "#{number / 60} hour" if number % 60 == 0
    "#{number} minute"
  
  # Displays the open games dialog.
  displayOpenGames: ->
    $("#open-games").modal()
    @displayOpenGamePage(0)
  
  # Displays the specified page of open games.
  displayOpenGamePage: (page) ->
    @openGamePage = page
    $("#open-games button").attr "disabled", "disabled"
    @showAlertPending("open-games")
    $.get $("#canvas").attr("open-games-path"), { page: page }, (data, status) =>  
      $("#open-games button").removeAttr "disabled"
      @clearAlertPending("open-games")
      if data.info.length == 0
        $("#open-games .panel-group").html "No open games found.<br><br>" +
          "<button id='create-new-game' class='btn btn-success btn-block'>" +
          "<span class='glyphicon glyphicon-glass'></span> Create New Game</button>"
        $("#open-games #create-new-game").click (event) =>
          $("#open-games").modal("hide")
          @displayNewGame()
      else
        $("#open-games .panel-group").html ""
        for info in data.info
          $("#open-games .panel-group").append @createGameInfoElement(info, info.joined, true, true, "open-games")
      if @openGamePage == 0
        $("#open-games #back").addClass "disabled"
      else
        $("#open-games #back").removeClass "disabled"
      if data.continues
        $("#open-games #next").removeClass "disabled"
      else
        $("#open-games #next").addClass "disabled"
      
  # Displays the new game dialog.
  displayNewGame: ->
    $("#loading").modal()
    $.get $("#canvas").attr("published-tracks-path"), (data, status) =>
      $("#loading").modal("hide")
      tracks = ""
      for track in data
        tracks += "<option value='#{track.id}'>#{track.name}</option>"
      $("#new-game #track").html tracks
      $("#new-game").modal()
  
  # Displays the rankings dialog.
  displayRankings: ->
    $("#rankings").modal()
    @selectRankingsTab("prompts")
    
  # Displays the invite player dialog.
  displayInvitePlayer: (gameId) ->
    @gameId = gameId
    $("#invite-player #facebook-invite").css "display", (if @facebook then "block" else "none")
    $("#invite-player").modal()
  
  # Displays the preferences dialog.
  displayPreferences: () ->
    $("#loading").modal()
    $("#preferences #push-notifications-container").css "display", (if @pushAvailable then "block" else "none")
    $.get $("#canvas").attr("preferences-path"), (data, status) =>
      $("#loading").modal("hide")
      $("#preferences #email-notifications").get(0).checked = data.emailNotifications
      $("#preferences #push-notifications").get(0).checked = @pushEnabled
      $("#preferences").modal()
      
  # Displays the next notice, if any.
  displayNextNotice: ->
    $("#notice").modal("hide")
    if @notices.length == 0
      $("#control").css "display", "none"
      @playfield.base.removeAllIntersectableFeatures()
      @displayMainMenu()
      return
    notice = @notices.shift()
    switch notice.type
      when "tutorial" then @tutorial.display => @displayNextNotice()
      when "game_invite" then @displayGameInvite(notice.info, notice.sender, notice.facebookId, notice.message)
      when "game_results" then @displayGameResults(notice.playerId, notice.gameId, notice.trackRevision,
        notice.results, notice.secret, notice.playerInfo, notice.gameInfo, notice.secondsRemaining, false)
  
  # Displays a game invite notice.
  displayGameInvite: (info, sender, facebookId, message) ->
    senderName = sender
    if facebookId?
      senderName = "<a href='https://facebook.com/#{facebookId}' target='_blank'>" + senderName + "</a>"
    $("#notice .modal-content").html "<div class='modal-header'>" +
      "<button class='close' data-dismiss='modal'>&times;</button> " +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-user'></span> Game Invite</h4>" +
      "</div>" +
      "<div class='modal-body centered'>" +
      @getFacebookPicture(facebookId) +
      "You have been invited by #{senderName} to join a game.<br><br>" +
      (if message.length == 0 then "" else "'#{message}'<br><br>") +
      "<div class='panel-group text-left'></div>" +
      "<div id='alert-container'></div>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='decline' class='btn btn-success'><span class='glyphicon glyphicon-thumbs-down'></span> Decline</button>" +
      "<button class='btn btn-success' data-dismiss='modal'>Postpone</button>" +
      "<button id='accept' class='btn btn-success'><span class='glyphicon glyphicon-thumbs-up'></span> Accept</button>" +
      "</div>"
    $("#control").css "display", "none"
    $("#notice .panel-group").append @createGameInfoElement(info, false, false)
    notice = $("#notice").get(0)
    answerGameInvite = (accept) =>
      $(notice).find("button").attr "disabled", "disabled"
      $(notice).find("#alert-container").html "<img src='/assets/loading.gif'>"
      $.post $("#canvas").attr("game-invite-answer-path"), { game_id: info.id, accept: accept }, (data, status) =>
        $(notice).modal("hide")
    $(notice).find("#decline").click -> answerGameInvite(false)
    $(notice).find("#accept").click -> answerGameInvite(true)
    $(notice).one "hidden.bs.modal", => @displayNextNotice()
    $(notice).modal()

  # Displays game results.
  displayGameResults: (playerId, gameId, trackRevision, results, secret, playerInfo, gameInfo, secondsRemaining, replay) ->
    canceller = =>
      alert "Sorry, you missed the cutoff for this turn."
      @timeoutId = undefined
      @playfield.base.removeAllIntersectableFeatures()
      $("#control").css "display", "none"
      $("#control-left").css "display", "none"
      $("#notice").css "display", "none"
      $("#static-notice").css "display", "none"
      @fetchNotices()
    @timeoutId = setTimeout(canceller, secondsRemaining * 1000)
    starter = =>
      $(notice).modal("hide")
      @playfield.setPlayerId(playerId)
      @gameId = gameId
      @turnNumber = gameInfo.turnNumber
      $("#loading").modal()
      $.get $("#canvas").attr("revision-path").replace("0", trackRevision), (data, status) =>
        $("#loading").modal("hide")
        @playfield.setJSON JSON.parse(data.data)
        @results = JSON.parse(results)
        @secret = JSON.parse(secret)
        @playerInfo = playerInfo
        if @results.preState? then @displayGameVotes() else @displayGameLeaderboard(true)
    if replay
      starter()
      return
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<button id='postpone' class='close'>&times;</button>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-time'></span> Ready for Turn</h4>" +
      "</div>" +
      "<div class='modal-body'>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='later' class='btn btn-success'>Postpone</button>" +
      "<button id='start-turn' class='btn btn-success'>Start Turn</button>" +
      "</div>" 
    notice = $("#static-notice").get(0)
    $(notice).find(".modal-body").append @createGameInfoElement(gameInfo, true, false, false)
    postponer = =>
      $(notice).modal("hide")
      @postponeGame()
    $(notice).find("#postpone").click postponer
    $(notice).find("#later").click postponer
    $(notice).find("#start-turn").click starter
    $(notice).modal()
    
  # Displays the game votes.
  displayGameVotes: ->
    @setupPreState()
    $("#control").css "display", "none"
    @prompts = (if @results.lastLastPrompts? then @results.lastLastPrompts[...] else null)
    @promptNumber = 0
    @responses = @results.lastResponses[...]
    @responsePlayerIds = (if @results.lastResponsePlayerIds? then @results.lastResponsePlayerIds[...] else null)
    @votes = @results.votes[...]
    @displayNextVotes()
  
  # Sets up the pre-state pucks.
  setupPreState: (first = true) ->
    @features = []
    @pucks = []
    @haveMoves = false
    for json in @results.preState
      feature = Feature.fromJSON(json)
      feature.setPlayfield @playfield
      if feature.playerId == @playfield.playerId
        @playfield.centerTranslationOnPath(feature.translation, if first then 0 else 0.5)
      @playfield.base.addFeature feature
      @features.push feature
      @setPromptClickHandler(feature) if feature.prompt?
      continue unless feature.playerId?
      @haveMoves = true if feature.queue.length > 0
      @pucks.push feature
      @updatePlayerInfo feature if first
      @setPuckClickHandler feature
    
  # Displays the next set of votes in sequence, if any.
  displayNextVotes: ->
    if @votes.length == 0
      @displayGameResponses()
      return
    prompt = @prompts.shift()
    @promptNumber++
    responses = @responses.shift()
    responsePlayerIds = @responsePlayerIds.shift()
    votes = @votes.shift()
    combinedResponses = []
    for index in [0...responses.length]
      combinedResponses.push { playerId: responsePlayerIds[index], response: responses[index], votes: votes[index] }
    combinedResponses.sort (a, b) -> b.votes - a.votes
    responseRows = ""
    highest = combinedResponses[0].votes
    for combinedResponse in combinedResponses
      responseRows += "<tr><td>#{if combinedResponse.votes == 0 then "" else combinedResponse.votes}" +
        "#{if combinedResponse.votes == highest then " <span class='glyphicon glyphicon-star'></span>" else ""}</td>" +
        "<td>'#{combinedResponse.response}'</td>" +
        "<td>#{@playerInfo[combinedResponse.playerId].iconAndName}</td></tr>"
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<button id='postpone' class='close'>&times;</button>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-check'></span> Prompt ##{@promptNumber} Votes</h4>" +
      @createGameBreadcrumbs(0) +
      "</div>" +
      "<div class='modal-body'><div id='prompt-container'>" +
      "<iframe id='prompt' src='#{prompt.inlineUrl}' class='full-width' height='375'></iframe>" +
      "<div id='responses'>" +
        "<table class='table'><tr><th>Votes</th><th>Response</th><th>Player</th></tr>" +
          responseRows + "</table>" +
      "</div>" +
      "</div></div>" +
      "<div class='modal-footer'>" +
      "<button id='show-responses' class='btn btn-success'>Show Votes</button>" +
      "<button id='full-url' class='btn btn-info'>Visit</button>" +
      (if @facebook then "<button id='share' class='btn btn-info'>Share</button>" else "") +
      "<button id='ok' class='btn btn-success' disabled='disabled'>OK</button>" +
      "</div>" 
    notice = $("#static-notice").get(0)
    $(notice).find("#postpone").click =>
      $(notice).modal("hide")
      @postponeGame()
    $(notice).find("#show-responses").click (event) =>
      $(notice).find("#ok").get(0).disabled = false 
      if $("#responses").css("display") == "none"
        $("#responses").css "display", "block"
        event.target.innerHTML = "Show Prompt"
      else
        $("#responses").css "display", "none"
        event.target.innerHTML = "Show Votes"
    $(notice).find("#full-url").click => window.open(prompt.fullUrl)
    $(notice).find("#share").click => @displayShareDialog(prompt,
      "#{@playerInfo[combinedResponses[0].playerId].name}: '#{combinedResponses[0].response}'")
    $(notice).find("#ok").click =>
      $(notice).modal("hide")
      @displayNextVotes()
    $(notice).modal()
  
  # Postpones the current game, showing the next notice.
  postponeGame: ->
    clearTimeout(@timeoutId)
    @timeoutId = undefined
    @playfield.base.removeAllIntersectableFeatures()
    @displayNextNotice()
    
  # Displays the game responses and allows the player to vote on them.
  displayGameResponses: ->
    @prompts = @results.lastPrompts[...]
    @responses = @results.responses[...]
    @responseIndices = @secret.responseIndices[...]
    @responsePlayerIds = @results.responsePlayerIds[...]
    @votes = []
    @ratings = []
    @promptNumber = 0
    @displayNextResponses()
  
  # Displays the next set of responses in sequence, if any.
  displayNextResponses: ->
    if @responses.length == 0
      @displayGamePreState()
      return
    prompt = @prompts.shift()
    @promptNumber++
    responses = @responses.shift()
    responseIndex = @responseIndices.shift()
    responsePlayerId = @responsePlayerIds.shift() if @responsePlayerIds.length > 0
    responseRows = ""
    if responses.length == 1
      responseRows = "<table class='table'><tr><td>'#{responses[0]}'</td>" +
        "<td>#{@playerInfo[responsePlayerId].iconAndName}</td></tr></table>"
    else
      for index in [0...responses.length]
        if index != responseIndex
          responseRows += "<button id='response-#{index}' class='btn btn-default btn-block button-wrap'>'" +
            "#{responses[index]}'</button>"
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<button id='postpone' class='close'>&times;</button>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-list'></span> Prompt ##{@promptNumber} Responses</h4>" +
      @createGameBreadcrumbs(1) +
      "</div>" +
      "<div class='modal-body'><div id='prompt-container'>" +
      "<iframe id='prompt' src='#{prompt.inlineUrl}' class='full-width' height='375'></iframe>" +
      "<div id='responses'>" +
      (if responses.length == 1 then "Only one response:<br><br>" else "Choose your favorite response:<br><br>") + 
      responseRows +
      "<br><div class='text-right'>(Optional) Rate Prompt:&nbsp; " +
      "<a href='#' id='dislike-prompt'><span class='glyphicon glyphicon-thumbs-down'></a> / " +
      "<a href='#' id='like-prompt'><span class='glyphicon glyphicon-thumbs-up'></a></div>" +
      "</div></div></div>" +
      "<div class='modal-footer'>" +
      "<button id='show-responses' class='btn btn-success'>Show Responses</button>" +
      "<button id='full-url' class='btn btn-info'>Visit</button>" +
      (if @facebook && responses.length == 1 then "<button id='share' class='btn btn-info'>Share</button>" else "") +
      (if responses.length == 1 then "<button id='ok' class='btn btn-success' " +
        "disabled='disabled'>OK</button>" else "") +
      "</div>" 
    notice = $("#static-notice").get(0)
    $(notice).find("#postpone").click =>
      $(notice).modal("hide")
      @postponeGame()
    $(notice).find("#show-responses").click (event) => 
      $(notice).find("#ok").get(0).disabled = false if responses.length == 1
      if $("#responses").css("display") == "none"
        $("#responses").css "display", "block"
        event.target.innerHTML = "Show Prompt"
      else
        $("#responses").css "display", "none"
        event.target.innerHTML = "Show Responses"
    rating = 0
    setRating = (newRating) ->
      rating = newRating
      $(notice).find("#like-prompt").css "color", (if rating == 1 then "blue" else "gray")
      $(notice).find("#dislike-prompt").css "color", (if rating == -1 then "blue" else "gray")
    setRating(0)
    for index in [0...responses.length]
      do (index) =>
        $(notice).find("#response-" + index).click =>
          @votes.push index
          @ratings.push rating
          $(notice).modal("hide") 
          @displayNextResponses()
    $(notice).find("#like-prompt").click (event) =>
      setRating(if rating == 1 then 0 else 1)
    $(notice).find("#dislike-prompt").click (event) =>
      setRating(if rating == -1 then 0 else -1)
    $(notice).find("#full-url").click => window.open(prompt.fullUrl)
    $(notice).find("#share").click => @displayShareDialog(prompt, "#{@playerInfo[responsePlayerId].name}: '#{responses[0]}'")
    $(notice).find("#ok").click =>
      @ratings.push rating
      $(notice).modal("hide")
      @displayNextResponses()
    $(notice).modal()
  
  # Displays the Facebook share dialog.
  displayShareDialog: (prompt, response) ->
    FB.ui {
      method: "feed"
      app_id: $("#fb-root").attr("app-id")
      link: prompt.fullUrl
      description: response
    }
  
  # Displays the game moves and allows the player to execute them.
  displayGamePreState: (replay = false) ->
    unless @haveMoves
      @playfield.base.removeFeature(feature) for feature in @features
      @displayGameLeaderboard(false)
      return
    $("#control").css "display", "block"
    slowButton = ""
    if replay
      slowButton = "<button id='slow-mo' class='btn btn-success btn-lg'>Go Slow!</button> "
    $("#control").html slowButton + "<button id='go' class='btn btn-primary btn-lg'>Go!</button>"
    handler = (event) =>
      $("#control").css "display", "none"
      @playfield.simulate @pucks, (if event.target.id == "go" then 1 else 0.5), =>
        $("#control").css "display", "block"
        $("#control").html "<button id='show-leaderboard' class='btn btn-primary btn-lg'>" +
          "Next <span class='glyphicon glyphicon-chevron-right'></span></button>"
        $("#control-left").css "display", "block"
        $("#control-left").html "<button id='replay' class='btn btn-success btn-lg'>Replay</button>"
        showLeaderboard = $("#show-leaderboard").get(0)
        $(showLeaderboard).click =>
          @playfield.base.removeFeature(feature) for feature in @features
          @displayGameLeaderboard(false)
        replay = $("#replay").get(0)
        $(replay).click =>
          $("#control-left").css "display", "none"
          @playfield.base.removeFeature(feature) for feature in @features
          @setupPreState(false)
          @displayGamePreState(true)
    $($("#go").get(0)).click handler
    if replay
      $($("#slow-mo").get(0)).click handler
          
  # Displays the game leaderboard.
  displayGameLeaderboard: (first) ->
    if first
      @votes = []
      @ratings = []
    leaders = []
    for json in @results.state
      feature = Feature.fromJSON(json)
      feature.setPlayfield @playfield
      if feature.playerId == @playfield.playerId
        @playerPuck = feature
        @playerPuck.setMoveDistances @secret.moveDistances
        @playfield.centerTranslationOnPath(feature.translation, if first then 0 else 0.5)
      @playfield.base.addFeature feature
      @setPromptClickHandler(feature) if feature.prompt?
      continue unless feature.playerId?
      @updatePlayerInfo feature if first
      @setPuckClickHandler feature, true
      progress = (if feature.finishOrder? then 100 - feature.finishOrder else @playfield.getProgress(feature.translation))
      leaders.push { playerId: feature.playerId, progress: progress }
    leaders.sort (a, b) -> b.progress - a.progress
    rows = ""
    position = 0
    progress = Number.MAX_VALUE
    places = [ "WINNER!", "SECOND PLACE", "THIRD PLACE" ]
    for leader in leaders
      if leader.progress < progress
        position++
        progress = leader.progress
      positionString = (if progress > 1 && position <= places.length then places[position - 1] else position)
      rows += "<tr><td>#{positionString}</td><td>#{Math.floor(Math.min(progress, 1) * 100)}%</td>" +
        "<td>#{@playerInfo[leader.playerId].iconAndName}</td></tr>"
    $("#notice .modal-content").html "<div class='modal-header'>" +
      "<button id='postpone' class='close'>&times;</button>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-flag'></span> Leaderboard</h4>" +
      @createGameBreadcrumbs(3) +
      "</div>" +
      "<div class='modal-body'>" +
      "<table class='table'><tr><th>Position</th><th>Progress</th><th>Name</th></tr>" +
      rows +
      "</table>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='ok' class='btn btn-success'>OK</button>" +
      "</div>"
    $("#control").css "display", "none"
    $("#control-left").css "display", "none"
    notice = $("#notice").get(0)
    $(notice).find("#postpone").click =>
      $(notice).modal("hide")
      @postponeGame()
    $(notice).find("#ok").click =>
      $(notice).modal("hide")
      @displayGamePrompts()
    $(notice).modal()
  
  # Creates the "breadcrumbs" section for the current game.
  createGameBreadcrumbs: (stage) ->
    @createBreadcrumbs(stage, @results.preState?, @results.votes? && @results.votes.length > 0, @results.responses.length > 0,
      @haveMoves, @results.prompts.length > 0, @secret.moveDistances.length > 0, false)
  
  # Creates the "breadcrumbs" section.
  createBreadcrumbs: (stage, preState, votes, responses, haveMoves, prompts, moveDistances, tutorial) ->
    spans = ""
    if preState
      if votes
        spans = @addBreadcrumbSpan spans, "<span class='glyphicon glyphicon-check'></span>", stage, 0
      if responses
        spans = @addBreadcrumbSpan spans, "<span class='glyphicon glyphicon-list'></span>", stage, 1
      if haveMoves
        spans = @addBreadcrumbSpan spans, "<span class='glyphicon glyphicon-play'></span>", stage, 2
    spans = @addBreadcrumbSpan spans, "<span class='glyphicon glyphicon-flag'></span>", stage, 3
    if prompts
      spans = @addBreadcrumbSpan spans, "<span class='glyphicon glyphicon-comment'></span>", stage, 4
    if moveDistances
      spans = @addBreadcrumbSpan spans, "<span class='glyphicon glyphicon-record'></span>", stage, 5
    "<div class='breadcrumbs#{if tutorial then " tutorial" else ""}'>" + spans + "</div>"
    
  # Adds a span to the string provided.
  addBreadcrumbSpan: (spans, span, stage, spanStage) ->
    if spans.length == 0
      span
    else if stage < spanStage
      spans + "<span class='future'> - " + span + "</span>"
    else
      spans + " - " + span
  
  # Displays the prompts and allows the player to respond to them.
  displayGamePrompts: ->
    @prompts = @results.prompts[...]
    @promptNumber = 0
    @responses = []
    @displayNextPrompt()
  
  # Retrieves the icon from the specified feature and sets it in the player info.
  updatePlayerInfo: (feature) ->
    info = @playerInfo[feature.playerId]
    unless info?
      info = @playerInfo[feature.playerId] = { name: "(left game)" }
    info.icon = feature.getIconURL()
    info.iconAndName = "<img src='#{info.icon}'> "
    if info.facebookId?
      info.iconAndName += "<a href='https://facebook.com/#{info.facebookId}' target='_blank'>#{info.name}</a>"
    else
      info.iconAndName += "#{info.name}"
  
  # Sets the click handler for the specified puck.
  setPuckClickHandler: (puck, controlled = false) ->
    if puck.playerId == @playfield.playerId && controlled
      puck.setClickHandler null
      return
    playerInfo = @playerInfo[puck.playerId];
    puck.setClickHandler =>
      $("#notice .modal-content").html "<div class='modal-header'>" +
        "<h4 class='modal-title'><span class='glyphicon glyphicon-user'></span> Player Info</h4>" +
        "</div>" +
        "<div class='modal-body centered'>" +
        @getFacebookPicture(playerInfo.facebookId) + "#{playerInfo.iconAndName}" +
        "</div>" +
        "<div class='modal-footer'>" +
        "<button class='btn btn-success' data-dismiss='modal'>OK</button>" +
        "</div>"
      notice = $("#notice").get(0)
      $(notice).modal()
  
  # Returns a Facebook picture snippet if the provided id is valid.
  getFacebookPicture: (facebookId) ->
    return "" if !facebookId?
    "<img src='//graph.facebook.com/v2.4/" + facebookId + "/picture'><br><br>"
    
  # Sets the click handler for the specified prompt.
  setPromptClickHandler: (feature) ->
    feature.setClickHandler =>
      $("#notice .modal-content").html "<div class='modal-header'>" +
        "<h4 class='modal-title'><span class='glyphicon glyphicon-comment'></span> Prompt</h4>" +
        "</div>" +
        "<div class='modal-body'>" +
        "<iframe src='#{feature.prompt.inlineUrl}' class='full-width' height='375'></iframe>" +
        "</div>" +
        "<div class='modal-footer'>" +
        "<button id='full-url' class='btn btn-info'>Visit Full Page</button>" +
        "<button class='btn btn-success' data-dismiss='modal'>OK</button>" +
        "</div>"
      notice = $("#notice").get(0)
      $(notice).find("#full-url").click => window.open(feature.prompt.fullUrl)
      $(notice).modal()
      
  # Displays the next prompt in sequence, if any.
  displayNextPrompt: ->
    if @prompts.length == 0
      @displayGameState()
      return
    prompt = @prompts.shift()
    @promptNumber++
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<button id='postpone' class='close'>&times;</button>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-comment'></span> Prompt ##{@promptNumber}</h4>" +
      @createGameBreadcrumbs(4) +
      "</div>" +
      "<div class='modal-body'>" +
      "<iframe src='#{prompt.inlineUrl}' class='full-width' height='350'></iframe><br>" +
      "<input id='response' class='form-control' type='text' maxlength='140'" +
        "placeholder='Enter response...'></input>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='full-url' class='btn btn-info'>Visit Full Page</button>" +
      "<button id='submit' class='btn btn-success' data-dismiss='modal' disabled='disabled'>Submit</button>" +
      "</div>"
    notice = $("#static-notice").get(0)
    $(notice).find("#postpone").click =>
      $(notice).modal("hide")
      @postponeGame()
    $(notice).find("#response").on "input", (event) =>
      $(notice).find("#submit").get(0).disabled = (event.target.value.length == 0)
    $(notice).find("#full-url").click => window.open(prompt.fullUrl)
    $(notice).find("#submit").click =>
      $(notice).modal("hide")
      @responses.push $(notice).find("#response").val()
      @displayNextPrompt()
    $(notice).modal()
    
  # Displays the game state after the moves and allows the player to set the next move.
  displayGameState: ->
    noMoveDistances = (@playerPuck.moveDistances.length == 0)
    moveSender = =>
      clearTimeout(@timeoutId)
      @timeoutId = undefined
      $("#control").css "display", "none"
      $("#control-left").css "display", "none"
      if noMoveDistances
        $("#loading").modal()
      else
        $("#static-notice .modal-content").html "<div class='modal-header'>" +
          "<h4 class='modal-title'>Sending Moves...</h4>" +
          "</div>" +
          "<div class='modal-body'>" +
          "<div id='alert-container' class='centered'></div>" +
          "</div>" +
          "<div class='modal-footer'>" +
          "<button id='ok' class='btn btn-success' disabled='disabled'>OK</button>" +
          "</div>"
        notice = $("#static-notice").get(0)
        $(notice).modal()
        @showAlertPending("static-notice")
      move = { votes: @votes, ratings: @ratings, responses: @responses }
      move.moves = (playerMove.toJSON() for playerMove in @playerPuck.getMoves())
      params = { game_id: @gameId, turn_number: @turnNumber, move: JSON.stringify(move) }
      $.post $("#canvas").attr("game-move-path"), params, (data, status) =>
        if noMoveDistances
          $("#loading").modal("hide")
          @displayNextNotice()
          return
        $(notice).find("#ok").removeAttr("disabled")
        if status == "success" && data == "success"
          @showAlert("static-notice", "Your moves have been submitted!", "success", false)
          $(notice).find("#ok").click =>
            $(notice).modal("hide")
            @displayNextNotice()
        else
          @showAlert("static-notice", (if status == "success" then data else status), "danger", false)
          $(notice).find("#ok").click =>
            $(notice).modal("hide")
            @playfield.base.removeAllIntersectableFeatures()
            @fetchNotices()
    if noMoveDistances
      moveSender()
      return
    controlLeft = $("#control-left").get(0)
    $(controlLeft).css "display", "block"
    buttons = ""
    actions = (PuckAction.fromJSON(action) for action in @secret.actions)
    for index in [0...actions.length]
      actions[index].index = index
      buttons += "<button id='action-#{index}' class='btn btn-success btn-lg btn-block'>#{actions[index].label}</button>"
    $(controlLeft).html "<div class='left-aligned' id='actions'>" + buttons +
      "</div><div class='label label-default' id='move-counter'>#{@playerPuck.moveDistances.length}</div>"
    for index in [0...actions.length]
      do (index) =>
        $(controlLeft).find("#action-" + index).click (event) =>
          $(event.target).css "display", "none"
          @playerPuck.addAction actions[index]
    @playerPuck.setActionRemovalListener (action) ->
      $(controlLeft).find("#action-" + action.index).css "display", "block"
    $("#control").css "display", "block"
    $("#control").html "<button id='send-moves' class='btn btn-primary btn-lg' disabled='disabled'>Send Moves</button>"
    sendMoves = $("#send-moves").get(0)
    @playerPuck.setMoveListener =>
      moveCount = @playerPuck.getLastPuck().moveDistances.length
      $("#control-left #move-counter").html "#{moveCount}"
      $("#control-left #move-counter").css "display", (if moveCount > 0 then "inline" else "none")
      sendMoves.disabled = (@playerPuck.getMoves().length == 0)
    $(sendMoves).click moveSender
      
    
# Initialize after loading.
$(document).on "ready, page:change", ->
  return if $("#canvas").length == 0
  element = $("#canvas").get(0)
  return if element.initialized
  element.initialized = true
  gameCanvas = new GameCanvas


