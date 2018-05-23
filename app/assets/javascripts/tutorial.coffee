# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

root = exports ? this

# Contains the tutorial bits factored out from GameCanvas. 
class root.Tutorial
  constructor: (@playfield, @gameCanvas) ->

  # Displays the tutorial
  display: (onComplete = null) ->
    @onComplete = onComplete
    $("#loading").modal()
    $.get "/tutorial_track.json", (data, status) =>
      $("#loading").modal("hide")
      @playfield.setJSON data
      @pucks = [
        new Puck(@playfield, new Point(272.5, 560), "royalblue", 1)
        @playerPuck = new Puck(@playfield, new Point(320, 560), "chartreuse", 2)
        new Puck(@playfield, new Point(367.5, 560), "silver", 3)
      ]
      @playfield.setPlayerId 2
      @playfield.centerTranslationOnPath @playerPuck.translation
      @gameCanvas.playerInfo = {
        "1": { name: "Some other bozo" }
        "2": { name: "YOU" }
        "3": { name: "Yet another schmuck" }
      }
      for puck in @pucks
        @gameCanvas.updatePlayerInfo puck
        @playfield.base.addFeature puck
      @playerPuck.setMoveDistances [ 150, 150 ]
      @target = new TextFeature(new Point(), 0, "\u00D7")
      @target.setFontSize 24
      @target.setFontFamily "sans-serif"
      @display1()
    
  # Displays the next segment of the tutorial.
  display1: ->
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<h4 class='modal-title'>Welcome!</h4>" +
      "</div>" +
      "<div class='modal-body'>" +
      "<p>Welcome to <strong>Snarky Pucks</strong>: the online party game where your rapier wit and stunning insight will " +
      "earn you bonuses beyond the mere admiration of your peers.</p>" +
      "<p>As you race against your friends along an obstacle-filled track, you'll be faced every day with a series of " +
      "prompts--like Wikipedia articles and news stories--that you must respond to in 140 characters or less.</p>" +
      "You and your fellow players will decide the best responses, and the winners will receive extras to speed them " +
      "along towards the finish line.</p>" +
      "<p>Let's start with a brief introduction to the game.  You can skip this at any time if you think you know what " +
      "the puck you're doing.</p>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='skip-tutorial' class='btn btn-success left-aligned'>Skip Tutorial</button>" +
      "<button id='next' class='btn btn-success'>Next <span class='glyphicon glyphicon-chevron-right'></span></button>" +
      "</div>"
    notice = $("#static-notice").get(0)
    $(notice).find("#skip-tutorial").click => @complete()
    $(notice).find("#next").click => @display2()
    $(notice).modal()
  
  # Displays the next segment of the tutorial.
  display2: ->
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-flag'></span> Turn 1: Leaderboard</h4>" +
      @gameCanvas.createBreadcrumbs(3, false, false, false, false, true, true, true) + 
      "</div>" +
      "<div class='modal-body'>" +
      "<p>Each game progresses through a series of turns--typically, one per day--and each turn consists of a number of " +
      "notifications and actions.</p>" +
      "<p>The first and last thing you'll see in the game is the leaderboard, which shows the positions and puck colors of " +
      "each player.  It looks like this:</p>" +
      "<br><table class='table'><tr><th>Position</th><th>Progress</th><th>Name</th></tr>" +
      "<tr><td>1</td><td>0%</td><td><img src='#{Puck.getIconURL("chartreuse", true)}'> YOU</td></tr>" +
      "<tr><td>1</td><td>0%</td><td><img src='#{Puck.getIconURL("royalblue")}'> Some other bozo</td></tr>" +
      "<tr><td>1</td><td>0%</td><td><img src='#{Puck.getIconURL("silver")}'> Yet another schmuck</td></tr>" +
      "</table>" +
      "<p>Note that your puck has a dot in the center.</p>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='skip-tutorial' class='btn btn-success left-aligned'>Skip Tutorial</button>" +
      "<button id='back' class='btn btn-success'><span class='glyphicon glyphicon-chevron-left'></span> Back</button>" +
      "<button id='next' class='btn btn-success'>Next <span class='glyphicon glyphicon-chevron-right'></span></button>" +
      "</div>"
    notice = $("#static-notice").get(0)
    $(notice).find("#skip-tutorial").click => @complete()
    $(notice).find("#back").click => @display1()
    $(notice).find("#next").click => @display3()
    $(notice).modal()
  
  # Displays the next segment of the tutorial.
  display3: ->
    @playfield.centerTranslationOnPath @playerPuck.translation
    @playerPuck.removeRest()
    @playerPuck.mousable = true
    @clearPopover true
    $("#control").css "display", "none"
    $("#control-left").css "display", "none"
    $("#control-top-right").css "display", "none"
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-comment'></span> Turn 1: Prompt</h4>" +
      @gameCanvas.createBreadcrumbs(4, false, false, false, false, true, true, true) + 
      "</div>" +
      "<div class='modal-body'>" +
      "<iframe src='/tutorial1.html' class='full-width' height='350'></iframe><br>" +
      "<input class='form-control' type='text' value='No problem! I&apos;m one snarky puck wit.' " +
        "disabled='disabled'></input>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='skip-tutorial' class='btn btn-success left-aligned'>Skip Tutorial</button>" +
      "<button id='back' class='btn btn-success'><span class='glyphicon glyphicon-chevron-left'></span> Back</button>" +
      "<button id='next' class='btn btn-success'>Next <span class='glyphicon glyphicon-chevron-right'></span></button>" +
      "</div>"
    notice = $("#static-notice").get(0)
    $(notice).find("#skip-tutorial").click => @complete()
    $(notice).find("#back").click => @display2()
    $(notice).find("#next").click => @display4()
    $(notice).modal()
    
  # Displays the next segment of the tutorial.
  display4: ->
    for puck in @pucks
      puck.removeRest()
      puck.queue = null
      @gameCanvas.setPuckClickHandler puck, true
    $("#static-notice").modal("hide")
    $("#control-left").css "display", "block"
    $("#control-left").html "<div class='left-aligned' id='actions'><button id='boost' class='btn btn-success btn-lg' " +
      "disabled='disabled'><span class='glyphicon glyphicon-forward'></span> Boost</button></div>" +
      "<div class='label label-default' id='move-counter'>2</div>"
    $("#control").css "display", "block"
    $("#control").html "<button id='back' class='btn btn-primary btn-lg'>" +
      "<span class='glyphicon glyphicon-chevron-left'></span> Back</button>" +
      "&nbsp; <button id='next' class='btn btn-primary btn-lg' disabled='disabled'>" +
      "Next <span class='glyphicon glyphicon-chevron-right'></span></button>"
    $("#control-top-right").css "display", "block"
    $("#control-top-right").html "<button id='skip-tutorial' class='btn btn-success'>Skip Tutorial</button>"
    control = $("#control-top-right").get(0)
    $(control).find("#skip-tutorial").click => @complete()
    control = $("#control").get(0)
    $(control).find("#back").click => @display3()
    $("#popover-target").popover {
      content: "Click/touch and drag to the X above to enter a move."
      placement: "auto top"
      title: "This is Your Puck"
      trigger: "manual"
      animation: false
    }
    @guideToTarget new Point(0, -150), @display5
  
  # Displays the next section of the tutorial.
  display5: ->
    @playerPuck.mousable = false
    @playerPuck.nextPuck.mousable = false
    $("#control-left #move-counter").html "1"
    $("#control-left").popover {
      content: "Click the Boost action to perform that action before your next move.  " +
        "Note also the counter that shows number of moves remaining."
      placement: "auto top"
      title: "These Are Your Actions"
      trigger: "manual"
      animation: false
    }
    $("#control-left").popover("show")
    boost = $("#control-left #boost").get(0)
    boost.disabled = false
    $(boost).click =>
      $("#control-left").popover("destroy")
      @playerPuck.nextPuck.mousable = true
      @playerPuck.nextPuck.setMoveDistances [ 150 ]
      @playerPuck.addAction new Boost()
      $("#control-left #actions").html ""
      $("#popover-target").popover {
        content: "Move to the next X; note that Boost allows you to move farther.  You can also drag the board to pan around."
        placement: "auto top"
        title: "Enter Another Move"
        trigger: "manual"
        animation: false
      }
      @guideToTarget new Point(36, -222), @display6
      
  # Displays the next section of the tutorial.
  display6: ->
    @playerPuck.nextPuck.mousable = false
    @playerPuck.nextPuck.nextPuck.mousable = false
    $("#control-left").html ""
    $("#control").popover {
      content: "Click the Next button to send your moves for this turn."
      placement: "auto top"
      title: "Send Your Moves"
      trigger: "manual"
      animation: false
    }
    $("#control").popover("show")
    next = $("#control #next").get(0)
    next.disabled = false
    $(next).click =>
      @display7()
  
  # Displays the next section of the tutorial.
  display7: ->
    @setup7()
    $("#control").css "display", "none"
    $("#control-left").css "display", "none"
    $("#control-top-right").css "display", "none"
    @votedResponse = "Look at all the pucks I give."
    @otherResponse = "Let the snarks fly!"
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-list'></span> Turn 2: Responses</h4>" +
      @gameCanvas.createBreadcrumbs(1, true, false, true, true, true, true, true) + 
      "</div>" +
      "<div class='modal-body'>" +
      "<p>When the next turn is available (typically the next day), you must choose your favorite of " +
      "the other players' responses to the prompt.</p>" +
      "Click on one of the following:<br><br>" +
      "<button id='response-1' class='btn btn-default btn-block'>'#{@votedResponse}'</button>" +
      "<button id='response-2' class='btn btn-default btn-block'>'#{@otherResponse}'</button>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='skip-tutorial' class='btn btn-success left-aligned'>Skip Tutorial</button>" +
      "<button id='back' class='btn btn-success'><span class='glyphicon glyphicon-chevron-left'></span> Back</button>" +
      "</div>"
    notice = $("#static-notice").get(0)
    $(notice).find("#skip-tutorial").click => @complete()
    $(notice).find("#back").click => @display4()
    $(notice).find("#response-1").click => @display8(true)
    $(notice).find("#response-2").click =>
      [ @votedResponse, @otherResponse ] = [ @otherResponse, @votedResponse ] 
      @display8(true)
    $(notice).modal()
  
  # Displays the next section of the tutorial.
  display8: (setup = false) ->
    @setup7() unless setup
    $("#static-notice").modal("hide")
    $("#control").css "display", "block"
    $("#control").html "<button id='back' class='btn btn-primary btn-lg'>" +
      "<span class='glyphicon glyphicon-chevron-left'></span> Back</button>" +
      "&nbsp; <button id='next' class='btn btn-primary btn-lg'>Go!</button>"
    $("#control-top-right").css "display", "block"
    $("#control-top-right").html "<button id='skip-tutorial' class='btn btn-success'>Skip Tutorial</button>"
    control = $("#control-top-right").get(0)
    $(control).find("#skip-tutorial").click => @complete()
    control = $("#control").get(0)
    $(control).find("#back").click => @display7()
    $("#control").popover {
      content: "Click the Go! button to execute all players' moves for this turn."
      placement: "auto top"
      title: "Turn 2: Execute Moves"
      trigger: "manual"
      animation: false
    }
    $("#control").popover("show")
    next = $("#control #next").get(0)
    simulated = false
    $(next).click =>
      if simulated
        @playfield.centerTranslationOnPath @playerPuck.translation, 0.5
        @display9()
        return
      simulated = true
      $("#control").popover("destroy")
      next.disabled = true
      @playfield.simulate @pucks, 1, =>
        next.disabled = false
        next.innerHTML = "Next <span class='glyphicon glyphicon-chevron-right'></span>"
  
  # Shared setup between 7 and 8.
  setup7: ->
    @clearPopover true
    @playerPuck.mousable = true
    @playerPuck.setPosition new Point(320, 560)
    @playfield.centerTranslationOnPath @playerPuck.translation
    @playerPuck.queue = [ new Point(0, -150), new Boost(), new Point(36, -222) ]
    @playerPuck.setPlayfield @playfield
    @pucks[0].setPosition new Point(272.5, 560)
    @pucks[0].queue = [ new Point(-10, -150), new Boost(), new Point(39, -222) ]
    @pucks[0].setPlayfield @playfield
    @pucks[2].setPosition new Point(367.5, 560)
    @pucks[2].queue = [ new Point(11, -150), new Boost(), new Point(74, -213) ]
    @pucks[2].setPlayfield @playfield
    for puck in @pucks
      @gameCanvas.setPuckClickHandler puck, false
    
  # Displays the next section of the tutorial.
  display9: ->
    @clearPopover true
    @playerPuck.removeRest()
    @playerPuck.setActionRemovalListener undefined
    @playerPuck.setMoveListener undefined
    @playerPuck.removeAction()
    $("#control").css "display", "none"
    $("#control-left").css "display", "none"
    $("#control-top-right").css "display", "none"
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-check'></span> Turn 3: Votes</h4>" +
      @gameCanvas.createBreadcrumbs(0, true, true, true, true, true, true, true) + 
      "</div>" +
      "<div class='modal-body'>" +
      "<p>When you start the next turn, you'll see the people responsible for each response and the number of votes they " +
      "received.</p>" +
      "<p>The player with the most votes receives an additional action for the turn.</p><br>" +
      "<table class='table'><tr><th>Votes</th><th>Response</th><th>Player</th></tr>" +
      "<tr><td>2</td><td>'No problem! I&apos;m one snarky puck wit.'</td>" +
        "<td>#{@gameCanvas.playerInfo[2].iconAndName}</td></tr>" +
      "<tr><td>1</td><td>'#{@votedResponse}'</td>" +
        "<td>#{@gameCanvas.playerInfo[1].iconAndName}</td></tr>" +
      "<tr><td>0</td><td>'#{@otherResponse}'</td>" +
        "<td>#{@gameCanvas.playerInfo[3].iconAndName}</td></tr>" +
      "</table>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='skip-tutorial' class='btn btn-success left-aligned'>Skip Tutorial</button>" +
      "<button id='back' class='btn btn-success'><span class='glyphicon glyphicon-chevron-left'></span> Back</button>" +
      "<button id='next' class='btn btn-success'>Next <span class='glyphicon glyphicon-chevron-right'></span></button>" +
      "</div>"
    notice = $("#static-notice").get(0)
    $(notice).find("#skip-tutorial").click => @complete()
    $(notice).find("#back").click => @display8()
    $(notice).find("#next").click => @display10()
    $(notice).modal()
  
  # Displays the next section of the tutorial.
  display10: ->
    @gameCanvas.setPuckClickHandler @playerPuck, true
    @playerPuck.setMoveDistances [ 150, 150 ]
    $("#static-notice").modal("hide")
    $("#control-left").css "display", "block"
    $("#control-left").html "<div class='left-aligned' id='actions'><button id='boost' " +
      "class='btn btn-success btn-lg btn-block'>" +
      "<span class='glyphicon glyphicon-forward'></span> Boost</button>" +
      "<button id='extra' class='btn btn-success btn-lg btn-block'>" +
      "<span class='glyphicon glyphicon-plus'></span> Extra</button></div>" +
      "<div class='label label-default' id='move-counter'>2</div>"
    $("#control").css "display", "block"
    $("#control").html "<button id='back' class='btn btn-primary btn-lg'>" +
      "<span class='glyphicon glyphicon-chevron-left'></span> Back</button>" +
      "&nbsp; <button id='finish' class='btn btn-primary btn-lg' disabled='disabled'>" +
      "Finish!</button>"
    $("#control-top-right").css "display", "block"
    $("#control-top-right").html "<button id='skip-tutorial' class='btn btn-success'>Skip Tutorial</button>"
    control = $("#control-top-right").get(0)
    $(control).find("#skip-tutorial").click => @complete()
    control = $("#control").get(0)
    $(control).find("#back").click => @display9()
    finish = $(control).find("#finish").get(0)
    $(finish).click => @finish()
    control = $("#control-left").get(0)
    $(control).find("#boost").click (event) =>
      $(event.target).css "display", "none"
      action = new Boost()
      action.button = event.target
      @playerPuck.addAction(action)
    $(control).find("#extra").click (event) =>
      $(event.target).css "display", "none"
      action = new Extra()
      action.button = event.target
      @playerPuck.addAction(action)
    @playerPuck.setActionRemovalListener (action) -> $(action.button).css "display", "block"
    @playerPuck.setMoveListener =>
      moveCount = @playerPuck.getLastPuck().moveDistances.length
      $("#control-left #move-counter").html "#{moveCount}"
      $("#control-left #move-counter").css "display", (if moveCount > 0 then "inline" else "none")
      finish.disabled = @playfield.getProgress(@playerPuck.getLastPuck().translation) < 1
    $("#popover-target").popover {
      content: "Use your Extra move action and plot a series of moves to the checkered finish line on the right.  " +
        "Don't be stingy with your actions; you'll get a new set each turn."
      placement: "auto top"
      title: "Head for the Finish Line!"
      trigger: "manual"
      animation: false
    }
    @guideToTarget null, null
  
  # Guides the player to a target move.
  guideToTarget: (move, nextFn) ->
    lastPuck = @playerPuck.getLastPuck()
    follower = (finished) =>
      unless finished
        $("#popover-target").popover("hide")
        return
      $("#popover-target").css "left", lastPuck.bounds.left() - @playfield.base.translation.x
      $("#popover-target").css "top", lastPuck.bounds.top() - @playfield.base.translation.y
      $("#popover-target").css "width", lastPuck.bounds.width
      $("#popover-target").css "height", lastPuck.bounds.height
      $("#popover-target").css "display", "block"
      $("#popover-target").popover("show")
      @playfield.base.addFeature @target if move?
    @playfield.translationListener = follower
    follower(true)
    @target.setPosition lastPuck.translation.translated(move.x, move.y) if move?
    lastPuck.placingListener = (placing) =>
      if placing
        @clearPopover()
      else
        if move? && lastPuck.nextPuck? && lastPuck.nextPuck.translation.distance(@target.translation) < Puck.RADIUS
          lastPuck.placingListener = null
          lastPuck.removeRest()
          lastPuck.queue = [ move ]
          lastPuck.setPlayfield @playfield
          @playfield.base.removeFeature @target
          $("#popover-target").popover("destroy")
          nextFn.call(_this)
        else unless (!move? && lastPuck.nextPuck?)
          lastPuck.removeRest()
          @playfield.translationListener = follower
          follower(true)
  
  # Displays the finish dialog.
  finish: ->
    $("#control").css "display", "none"
    $("#control-left").css "display", "none"
    $("#control-top-right").css "display", "none"
    $("#static-notice .modal-content").html "<div class='modal-header'>" +
      "<h4 class='modal-title'><span class='glyphicon glyphicon-flag'></span> Final Results</h4>" +
      "</div>" +
      "<div class='modal-body'>" +
      "<p>You win!  Had this been a real game, you would be experiencing elation and a great sense of accomplishment.</p>" +
      "<br><table class='table'><tr><th>Position</th><th>Progress</th><th>Name</th></tr>" +
      "<tr><td>WINNER!</td><td>100%</td><td><img src='#{Puck.getIconURL("chartreuse", true)}'> YOU</td></tr>" +
      "<tr><td>2</td><td>60%</td><td><img src='#{Puck.getIconURL("silver")}'> Yet another schmuck</td></tr>" +
      "<tr><td>3</td><td>42%</td><td><img src='#{Puck.getIconURL("royalblue")}'> Some other bozo</td></tr>" +
      "</table>" +
      "<p>Now, try your puck in a game with your friends!</p>" +
      "</div>" +
      "<div class='modal-footer'>" +
      "<button id='complete' class='btn btn-success'>Complete Tutorial</button>" +
      "</div>"
    notice = $("#static-notice").get(0)
    $(notice).find("#complete").click => @complete()
    $(notice).modal()
  
  # Completes the tutorial.
  complete: ->
    @clearPopover true
    $("#static-notice,#control-left,#control,#control-top-right").find("button").attr "disabled", "disabled"    
    $.post $("#canvas").attr("complete-tutorial-path"), {}, (data, status) =>
      $("#static-notice").modal("hide")
      $("#control").css "display", "none"
      $("#control-left").css "display", "none"
      $("#control-top-right").css "display", "none"
      @playfield.setJSON null
      @onComplete()
  
  # Removes the popover and associated bits.
  clearPopover: (destroy = false) ->
    $("#control-left").popover("destroy")
    $("#control").popover("destroy")
    @playfield.base.removeFeature @target if destroy
    $("#popover-target").popover(if destroy then "destroy" else "hide")
    @playfield.translationListener = null
    @playerPuck.placingListener = null if destroy
    $("#popover-target").css "display", "none"
    
