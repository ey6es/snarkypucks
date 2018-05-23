# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

root = exports ? this

# Initialize after loading.
$(document).on "ready, page:change", ->
  return if $("#resimulation").length == 0
  element = $("#resimulation").get(0)
  return if element.initialized
  element.initialized = true
  playfield = new Playfield
  updateLayerSizes = ->
    playfieldDiv = $("#playfield").get(0)
    playfield.base.canvas.width = playfieldDiv.clientWidth
    playfield.base.canvas.height = playfieldDiv.clientHeight
    playfield.base.dirty()
    playfield.overlay.canvas.width = playfieldDiv.clientWidth
    playfield.overlay.canvas.height = playfieldDiv.clientHeight
    playfield.overlay.dirty()
  $(window).resize -> # preserve center when resizing
    cx = playfield.base.translation.x + Math.round(playfield.base.canvas.width / 2)
    cy = playfield.base.translation.y + Math.round(playfield.base.canvas.height / 2)
    updateLayerSizes()
    playfield.setTranslation(new Point(cx - Math.round(playfield.base.canvas.width / 2),
      cy - Math.round(playfield.base.canvas.height / 2)))
  updateLayerSizes()
  playfield.setJSON JSON.parse($("#resimulation").attr("track"))
  results = JSON.parse($("#resimulation").attr("results"))
  playerId = Number($("#resimulation").attr("player-id"))
  pucks = []
  for json in results.preState
    feature = Feature.fromJSON(json)
    feature.setPlayfield playfield
    playfield.base.addFeature(feature)
    if feature.playerId?
      pucks.push feature
      if feature.playerId == playerId
        feature.debug = true
  playfield.simulate(pucks)
  
