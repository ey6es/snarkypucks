# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

root = exports ? this

$(document).on "ready, page:change", ->
  # facebook invite bits
  return if $("#fb-root").length == 0 || $("#fb-root").attr("logged-in") != "true" || $("#new_game_invite").length == 0
  $.ajaxSetup { cache: true }
  $.getScript "//connect.facebook.net/en_US/sdk.js", ->
    FB.init { xfbml: 1, appId: $("#fb-root").attr("app-id"), version: "v2.3" }
    FB.getLoginStatus (response) -> 
      if response.status == "connected"
        $("#facebook-invite").get(0).disabled = false
        $("#facebook-invite").click ->
          message = "Come join me in a game of Snarky Pucks!  " + $("#game_invite_message").val()
          FB.ui { method: "apprequests", message: message }, (response) ->
            return unless response.to?
            $("#fb-response").val JSON.stringify(response)
            $("#new_game_invite").get(0).submit()
