# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

root = exports ? this

$(document).on "ready, page:change", ->
  # facebook login bits
  return if $("#fb-root").length == 0
  logout = false
  if $("#fb-root").attr("logout") == "true"
    return unless $("#fb-root").attr("logged-in") == "true"
    logout = true
  else
    return unless $("#fb-root").attr("login") == "true"
  $(".fb-login-button").attr("onlogin", "checkLoginStatus()")
  $.ajaxSetup { cache: true }
  $.getScript "//connect.facebook.net/en_US/sdk.js", ->
    FB.init { xfbml: 1, appId: $("#fb-root").attr("app-id"), version: "v2.3" }
    root.checkLoginStatus = ->
      FB.getLoginStatus (response) -> 
        if response.status == "connected"
          if logout
            FB.logout ->
          else
            $("#fb-token").val response.authResponse.accessToken
            $("#login-form").get(0).submit()
    checkLoginStatus()
    
