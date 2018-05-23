# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

# Base class for editor tools.
class Tool
  # The world space radius within which we snap.
  @SNAP_RADIUS: 20
  
  constructor: (@editor, @id, @name) ->
    $("#tool").append "<option value='#{@id}'>#{@name}</option>"
    @options = document.createElement "div"
    @snap = true
    @allowsTemporaryTools = true
    @snapExclusions = []

  # Toggles position snapping.
  setSnap: (snap) ->
    @snap = snap
    @updateSnapIndicator()

  # Called on tool activation
  activate: (temporary = false) ->
    $("#tool-options").get(0).appendChild(@options) unless temporary
    @updateSnapIndicator()

  # Called on tool deactivation
  deactivate: (temporary = false) ->
    $("#tool-options").get(0).removeChild(@options) unless temporary
    @removeSnapIndicator()

  # Handles a click event.
  click: (event) ->
  
  # Handles a mouse down event.
  mousedown: (event) ->
  
  # Handles a mouse up event.
  mouseup: (event) ->
  
  # Handles a mouse enter event.
  mouseenter: (event) ->
    @updateSnapIndicator()
    
  # Handles a mouse out event.
  mouseleave: (event) ->
    @removeSnapIndicator()
    
  # Handles a mouse move event.
  mousemove: (event) ->
    @updateSnapIndicator()
  
  # Updates the snap indicator in response to mouse motion, etc.
  updateSnapIndicator: ->
    snapToGrid = $("#snap-to-grid").get(0).checked
    featureSnap = $("#feature-snap").val()
    unless @snap && (snapToGrid || featureSnap != "none") && @editor.mouseIn
      @removeSnapIndicator()
      @snappedPosition = @editor.playfield.overlay.getWorldPosition @editor.mouseClientX, @editor.mouseClientY
      return
    unless @snapIndicator
      @snapIndicator = new Circle()
      @snapIndicator.setStrokeStyle new Style("#000000")
      @snapIndicator.setFillStyle new Style("#FFFFFF")
      @editor.playfield.overlay.addFeature(@snapIndicator)
    @snappedPosition = @editor.playfield.base.getWorldPosition @editor.mouseClientX, @editor.mouseClientY
    snapped = false
    unless featureSnap == "none"
      closest = @editor.playfield.base.getSnapPosition(@snappedPosition, Tool.SNAP_RADIUS,
        featureSnap == "vertices-edges", @snapExclusions)
      if closest?
        @snappedPosition = closest
        snapped = true
    if snapToGrid && !snapped
      @snappedPosition.x = Math.round(@snappedPosition.x / @editor.playfield.grid.spacing) * @editor.playfield.grid.spacing
      @snappedPosition.y = Math.round(@snappedPosition.y / @editor.playfield.grid.spacing) * @editor.playfield.grid.spacing
      snapped = true
    @snappedPosition = @editor.playfield.overlay.getLayerPosition(@snappedPosition, @editor.playfield.base)
    @snapIndicator.setParameters @snappedPosition, 3
    @snapIndicator.setVisible snapped
  
  # Removes the snap indicator in response to leaving the canvas, etc.
  removeSnapIndicator: ->
    return unless @snapIndicator
    @editor.playfield.overlay.removeFeature(@snapIndicator)
    @snapIndicator = undefined
  
  # Handles a key down event.
  keydown: (event) ->
  
  # Handles a key up event.
  keyup: (event) ->
  
  
# A tool that allows panning around the playfield and editing the track globals.
class PanGlobalsTool extends Tool
  constructor: (editor) ->
    super editor, "panGlobals", "Pan/Globals"
    @snap = false
    exportPath = $("#editor").attr("export-path")
    importPath = $("#editor").attr("import-path")
    authToken = $("meta[name=csrf-token]").attr("content")
    @options.innerHTML =
      "Name: <input id='track-name' type='text' maxLength='255' value='New Track'></input><br><br>" +
      "Background Color: <input id='background-color' type='color' value='#FFFFFF'></input><br><br>" +
      "Show Grid: <input id='show-grid' type='checkbox' checked='checked'></input><br>" +
      "Grid Color: <input id='grid-color' type='color' value='#D0D0D0'></input><br>" +
      "Grid Spacing: <input id='grid-spacing' type='number' min='10' max='80' step='10' value='40'></input><br><br>" +
      "<button id='save-draft'>Save Draft</button><br>" +
      "<button id='revert-draft'>Revert to Last Draft</button><br>" +
      "<button id='revert-published' disabled='disabled'>Revert to Published</button><br>" +
      "<button id='publish'>Publish</button><br><br>" +
      "<div id='status'></div><br><br>" +
      "<form id='export' action='#{exportPath}' method='post'>" +
        "<input type='hidden' name='authenticity_token' value='#{authToken}'></input>" +
        "<input id='export-data' type='hidden' name='data'></input>" +
        "<input type='submit' value='Export to File'></input>" +
      "</form><br>" +
      "<form id='import' action='#{importPath}' method='post' enctype='multipart/form-data'>" +
        "<input type='hidden' name='authenticity_token' value='#{authToken}'></input>" +
        "<input type='hidden' name='_method' value='put'></input>" +
        "<input id='import-name' type='hidden' name='name'></input>" +
        "Import Draft from File:<br><input id='import-file' type='file' name='data'></input>" +
      "</form>"
    $(@options).find("#background-color").change (event) =>
      @editor.playfield.setBackgroundColor event.target.value
    $(@options).find("#show-grid").change (event) =>
      @editor.playfield.grid.setVisible event.target.checked
    $(@options).find("#grid-color").change (event) =>
      @editor.playfield.grid.setStrokeStyle new Style(event.target.value)
    $(@options).find("#grid-spacing").change (event) =>
      @editor.playfield.grid.setSpacing Number(event.target.value)
    $(@options).find("#save-draft").click =>
      data = { _method: "put", name: $(@options).find("#track-name").val(), data: JSON.stringify(@editor.playfield.getJSON()) }
      $.post $("#editor").attr("track-path"), data, (data, status) =>
        $(@options).find("#status").html data
    $(@options).find("#revert-draft").click =>
      return unless confirm "Are you sure you want to revert to the last saved draft?"
      @revert()
    $(@options).find("#revert-published").click =>
      return unless confirm "Are you sure you want to revert to the published version?"
      @revert(@publishedRevision)
    $(@options).find("#publish").click =>
      return unless confirm "Are you sure you want to publish this track?"
      data = { name: $(@options).find("#track-name").val(), data: JSON.stringify(@editor.playfield.getJSON()) }
      $.post $("#editor").attr("publish-path"), data, (data, status) =>
        $(@options).find("#status").html data
    $(@options).find("#export").submit =>
      $(@options).find("#export-data").attr "value", JSON.stringify(@editor.playfield.getJSON())
    $(@options).find("#import-file").change (event) =>
      $(@options).find("#import-name").attr "value", $(@options).find("#track-name").val()
      event.target.form.submit()
    @revert() #initial track load
  
  # "Reverts" (or simply loads) the latest stored revision.
  revert: (revision) ->
    if revision?
      path = $("#editor").attr("revision-path").replace("0", @publishedRevision)
    else
      path = $("#editor").attr("track-path")
    $.get path, (data, status) =>
        unless status == "success"
          $(@options).find("#status").html data
          return
        $(@options).find("#track-name").val(data.name)
        @publishedRevision = data.publishedRevision
        $(@options).find("#revert-published").get(0).disabled = !@publishedRevision?
        @editor.setSelection []
        @editor.clearUndoStacks()
        @editor.playfield.setJSON JSON.parse(data.data)
        $(@options).find("#background-color").get(0).value = @editor.playfield.backgroundColor
        $(@options).find("#show-grid").get(0).checked = @editor.playfield.grid.visible
        $(@options).find("#grid-color").get(0).value = @editor.playfield.grid.strokeStyle.style
        $(@options).find("#grid-spacing").get(0).value = @editor.playfield.grid.spacing
        $(@options).find("#status").html data.status
  
  deactivate: (temporary = false) ->
    $("#overlay-layer").css "cursor", "default"
    @lastPosition = undefined
    super temporary

  mousedown: (event) ->
    return unless event.button == 0
    event.preventDefault()
    event.target.style.cursor = "all-scroll"
    @lastPosition = new Point(event.clientX, event.clientY)
    
  mouseup: (event) ->
    return unless event.button == 0
    event.preventDefault()
    event.target.style.cursor = "default"
    @lastPosition = undefined
    
  mouseleave: (event) ->
    event.preventDefault()
    event.target.style.cursor = "default"
    @lastPosition = undefined
      
  mousemove: (event) ->
    return unless @lastPosition?
    @editor.playfield.setTranslation(new Point(
      @editor.playfield.base.translation.x + @lastPosition.x - event.clientX,
      @editor.playfield.base.translation.y + @lastPosition.y - event.clientY))
    @lastPosition = new Point(event.clientX, event.clientY)
  

# Base class for undoable actions.
class Action
  # Performs (redoes) the action.
  perform: (editor) ->
    editor.playfieldChanged()
  
  # Reverses (undoes) the action.
  reverse: (editor) ->
    editor.playfieldChanged()

  # If possible, merges the specified action into this one (and returns true).
  maybeMerge: (action) ->
    false


# An action that adds/removes a set of features.
class AddRemoveFeaturesAction extends Action
  constructor: (@add, @remove) ->
  
  perform: (editor) ->
    editor.playfield.base.addFeatures(@add)
    editor.playfield.base.removeFeatures(@remove)
    super editor
    
  reverse: (editor) ->
    editor.playfield.base.removeFeatures(@add)
    editor.playfield.base.addFeatures(@remove)
    super editor


# An action that translates a set of features.
class TranslateAction extends Action
  constructor: (@features, @x, @y, @group) ->
  
  perform: (editor) ->
    feature.translate(@x, @y) for feature in @features 
    
  reverse: (editor) ->
    feature.translate(-@x, -@y) for feature in @features
    
  maybeMerge: (action) ->
    return false if action.constructor != @constructor || action.group != @group
    @x += action.x
    @y += action.y
    true
    

# An action that rotates a set of features.
class RotateAction extends Action
  constructor: (@features, @x, @y, @angle, @group) ->
  
  perform: (editor) ->
    feature.rotate(@x, @y, @angle) for feature in @features 
    
  reverse: (editor) ->
    feature.rotate(@x, @y, -@angle) for feature in @features
    
  maybeMerge: (action) ->
    return false if action.constructor != @constructor || action.x != @x || action.y != @y || action.group != @group
    @angle += action.angle
    true
    
    
# An action that scales a set of features.
class ScaleAction extends Action
  constructor: (@features, @x, @y, @amount, @group) ->
  
  perform: (editor) ->
    feature.scale(@x, @y, @amount) for feature in @features 
    
  reverse: (editor) ->
    feature.scale(@x, @y, 1 / @amount) for feature in @features
    
  maybeMerge: (action) ->
    return false if action.constructor != @constructor || action.x != @x || action.y != @y || action.group != @group
    @amount *= action.amount
    true
    

# An action that sets a property on a set of features.
class SetPropertyAction extends Action
  constructor: (@features, @property, @setter, @value) ->
    @savedValues = (feature[@property] for feature in @features)
    
  perform: (editor) ->
    feature[@setter](@value) for feature in @features 
    editor.selectTool.selectionChanged()
    
  reverse: (editor) ->
    for index in [0...@features.length]
      @features[index][@setter](@savedValues[index])
    editor.selectTool.selectionChanged()


# An action that sets snap points for a set of features.
class SetSnapPointsAction extends Action
  constructor: (@featureSnapPoints, @oldPoint, @newPoint, @group) ->
    
  perform: (editor) ->
    featureSnapPoint.set(@newPoint) for featureSnapPoint in @featureSnapPoints
      
  reverse: (editor) ->
    featureSnapPoint.set(@oldPoint) for featureSnapPoint in @featureSnapPoints
  
  maybeMerge: (action) ->
    return false if action.constructor != @constructor || action.group != @group
    @newPoint = action.newPoint
    true

    
# Base class for select-like tools.
class AbstractSelectTool extends Tool
  constructor: (editor, id, name, @highlightColor) ->
    super editor, id, name
    @snap = false
    @highlighted = []

  activate: (temporary = false) ->
    super temporary
    @updateHighlighted()
    
  deactivate: (temporary = false) ->
    super temporary
    @setHighlighted []
    @editor.playfield.overlay.removeFeature(@feature) if @feature?
    @feature = undefined
    
  click: (event) ->
    return unless event.button == 0 && @highlighted.length > 0
    formerlyHighlighted = @highlighted
    @setHighlighted []
    @actOnFeatures formerlyHighlighted
    
  mousedown: (event) ->
    return unless event.button == 0
    event.preventDefault()
    @maybeClearSelection()
    position = @editor.playfield.overlay.getWorldPosition @editor.mouseClientX, @editor.mouseClientY 
    @feature = new Polygon([ position, position, position, position ])
    @feature.setStrokeStyle new Style(@highlightColor)
    @feature.setFillStyle new Style(@highlightColor)
    @feature.setFillAlpha 0.5
    @editor.playfield.overlay.addFeature(@feature)
  
  mouseup: (event) ->
    return unless event.button == 0
    event.preventDefault()
    @editor.playfield.overlay.removeFeature(@feature) if @feature?
    @feature = undefined
    
  mouseenter: (event) ->
    @updateHighlighted()
  
  mouseleave: (event) ->
    @setHighlighted []
    @editor.playfield.overlay.removeFeature(@feature) if @feature?
    @feature = undefined
    
  mousemove: (event) ->
    @updateHighlighted()
    return unless @feature?
    position = @editor.playfield.overlay.getWorldPosition @editor.mouseClientX, @editor.mouseClientY
    @feature.setVertices [
      @feature.vertices[0]
      new Point(position.x, @feature.vertices[0].y)
      position
      new Point(@feature.vertices[0].x, position.y)
    ]
  
  # Clears the selection if appropriate.
  maybeClearSelection: ->
    @editor.setSelection []
  
  # Updates the set of highlighted features according to the mouse/box state.
  updateHighlighted: ->
    if @feature?
      @setHighlighted @editor.playfield.base.getFeaturesIntersectingPolygon(
        @editor.playfield.base.getLayerPositions(@feature.vertices, @editor.playfield.overlay))
    else
      position = @editor.playfield.base.getWorldPosition @editor.mouseClientX, @editor.mouseClientY  
      features = @editor.playfield.base.getFeaturesIntersectingCircle(position, Tool.SNAP_RADIUS)
      features.sort Feature.SORT_FUNCTION
      @setHighlighted features.slice(Math.max(features.length - 1, 0))

  # Sets the set of highlighted features.
  setHighlighted: (highlighted) ->
    for feature in @highlighted
      if highlighted.indexOf(feature) == -1
        feature.setHighlightColor(if @editor.selection.indexOf(feature) == -1 then undefined else TrackEditor.SELECTION_COLOR) 
    for feature in highlighted
      feature.setHighlightColor(@highlightColor) if @highlighted.indexOf(feature) == -1
    @highlighted = highlighted
  
  # Performs our designated action on the specified features.
  actOnFeatures: (features) ->


# A tool that allows selecting features for manipulation.
class SelectTool extends AbstractSelectTool
  constructor: (editor) ->
    super editor, "select", "Select", "#D0D000"
    @options.innerHTML =
      "Transform: <select id='transform'>" +
      "<option value='translate'>Translate</option>" +
      "<option value='rotate'>Rotate</option>" +
      "<option value='scale-up'>Scale Up</option>" +
      "<option value='scale-down'>Scale Down</option>" +
      "</select><br>" +
      "<button id='select-all'>Select All</button><br><br>" +
      "<div id='properties'></div>"
    $(@options).find("#select-all").click =>
      @editor.setSelection @editor.playfield.base.getAllIntersectableFeatures()
  
  # Notifies the tool that the selection has changed.
  selectionChanged: ->
    properties = $(@options).find("#properties").get(0)
    $(properties).empty()
    return unless @editor.selection.length > 0
    $(properties).append new FeatureEditor(@editor, @editor.selection).element
    lines = (feature for feature in @editor.selection when feature.constructor == LineSegment)
    $(properties).append(new LineEditor(@editor, lines).element) if lines.length > 0
    stroked = (feature for feature in @editor.selection when feature.setStrokeStyle?)
    $(properties).append(new StrokeEditor(@editor, true, true, stroked).element) if stroked.length > 0
    filled = (feature for feature in @editor.selection when feature.setFillStyle?)
    $(properties).append(new StyleEditor(@editor, "<br>Fill", true, false, filled, "fill").element) if filled.length > 0
    images = (feature for feature in @editor.selection when feature.setURL?)
    $(properties).append(new ImageEditor(@editor, images).element) if images.length > 0
    text = (feature for feature in @editor.selection when feature.setText?)
    $(properties).append(new TextEditor(@editor, text).element) if text.length > 0
    
  deactivate: (temporary = false) ->
    super temporary
    @lastPosition = @firstPosition = undefined
    $("#overlay-layer").css "cursor", "default"
    
  mousedown: (event) ->
    return unless event.button == 0
    event.preventDefault()
    if @overSelection() && !@editor.ctrlDown
      @lastPosition = @firstPosition = new Point(event.clientX, event.clientY)
      event.target.style.cursor = "move"
    else
      super event
  
  mouseup: (event) ->
    return unless event.button == 0
    @lastPosition = @firstPosition = undefined
    event.target.style.cursor = "default"
    super event
  
  mouseleave: (event) ->
    super event
    @lastPosition = @firstPosition = undefined
    event.target.style.cursor = "default"
    
  mousemove: (event) ->
    if @lastPosition
      currentPosition = new Point(event.clientX, event.clientY)
      switch $(@options).find("#transform").val()
        when "translate"
          @editor.perform new TranslateAction(@editor.selection, event.clientX - @lastPosition.x,
            event.clientY - @lastPosition.y, @editor.actionGroup)
        when "rotate"
          unless Math.min(currentPosition.distance(@firstPosition), @lastPosition.distance(@firstPosition)) < Tool.SNAP_RADIUS
            center = @editor.playfield.base.getWorldPosition @firstPosition.x, @firstPosition.y
            angle = Math.atan2(event.clientY - @firstPosition.y, event.clientX - @firstPosition.x) -
              Math.atan2(@lastPosition.y - @firstPosition.y, @lastPosition.x - @firstPosition.x)
            @editor.perform new RotateAction(@editor.selection, center.x, center.y, angle, @editor.actionGroup)
        when "scale-up"
          unless Math.min(currentPosition.distance(@firstPosition), @lastPosition.distance(@firstPosition)) < Tool.SNAP_RADIUS
            center = @editor.playfield.base.getWorldPosition @firstPosition.x, @firstPosition.y
            amount = @firstPosition.distance(currentPosition) / @firstPosition.distance(@lastPosition)
            @editor.perform new ScaleAction(@editor.selection, center.x, center.y, amount, @editor.actionGroup)
        when "scale-down"
          unless Math.min(currentPosition.distance(@firstPosition), @lastPosition.distance(@firstPosition)) < Tool.SNAP_RADIUS
            center = @editor.playfield.base.getWorldPosition @firstPosition.x, @firstPosition.y
            amount = @firstPosition.distance(@lastPosition) / @firstPosition.distance(currentPosition)
            @editor.perform new ScaleAction(@editor.selection, center.x, center.y, amount, @editor.actionGroup)
      @lastPosition = currentPosition
    else
      super event
  
  maybeClearSelection: ->
    super unless @editor.ctrlDown
  
  setHighlighted: (highlighted) ->
    if @editor.ctrlDown then super highlighted
    else super (feature for feature in highlighted when @editor.selection.indexOf(feature) == -1)
  
  # Checks whether we're hovering over part of the selection.
  overSelection: ->
    position = @editor.playfield.base.getWorldPosition @editor.mouseClientX, @editor.mouseClientY
    for feature in @editor.selection
      return true if feature.intersectsCircle(position, Tool.SNAP_RADIUS)
    false
    
  actOnFeatures: (features) ->
    if @editor.ctrlDown
      selection = []
      for feature in features
        selection.push feature if @editor.selection.indexOf(feature) == -1
      for feature in @editor.selection
        selection.push feature if features.indexOf(feature) == -1
      @editor.setSelection selection
      @editor.makeTemporaryToolPermanent()
    else
      @editor.setSelection features


# A tool that allows erasing features directly.
class EraseTool extends AbstractSelectTool
  constructor: (editor) ->
    super editor, "erase", "Erase", "#FF0000"
    @options.innerHTML = "<button id='erase-all'>Erase All</button>"
    $(@options).find("#erase-all").click =>
      @editor.perform new AddRemoveFeaturesAction([], @editor.playfield.base.getAllIntersectableFeatures())
  
  actOnFeatures: (features) ->
    @editor.perform new AddRemoveFeaturesAction([], features)


# A tool that allows moving key points on features.
class AdjustTool extends Tool
  constructor: (editor) ->
    super editor, "adjust", "Adjust"
    @snap = false
    @featureSnapPoints = []
    
  activate: (temporary = false) ->
    super temporary
    @updateFeatureSnapPoints()
    
  deactivate: (temporary = false) ->
    super temporary
    @setFeatureSnapPoints []
    $("#overlay-layer").css "cursor", "default"
    @setSnap false
    
  mousedown: (event) ->
    return unless event.button == 0 && @featureSnapPoints.length > 0
    event.preventDefault()
    event.target.style.cursor = "crosshair"
    @featureSnapIndicator.setVisible false
    @setSnap true
  
  mouseup: (event) ->
    return unless event.button == 0
    event.target.style.cursor = "default"
    @setSnap false
    @updateFeatureSnapPoints()
    super event
  
  mouseenter: (event) ->
    super event
    @updateFeatureSnapPoints()
  
  mouseleave: (event) ->
    super event
    @setFeatureSnapPoints []
    event.target.style.cursor = "default"
    @setSnap false
    
  mousemove: (event) ->
    super event
    unless @snap
      @updateFeatureSnapPoints()
      return
    position = @editor.playfield.base.getLayerPosition(@snappedPosition, @editor.playfield.overlay)
    @editor.perform new SetSnapPointsAction(@featureSnapPoints, @featureSnapLocation, position, @editor.actionGroup)
    
  # Updates the set of feature snap points.
  updateFeatureSnapPoints: ->
    position = @editor.playfield.base.getWorldPosition @editor.mouseClientX, @editor.mouseClientY  
    [points, location] = @editor.playfield.base.getFeatureSnapPointsAndLocation(position, Tool.SNAP_RADIUS)
    @setFeatureSnapPoints points, location

  # Sets the set of feature snap points.
  setFeatureSnapPoints: (points, location = undefined) ->
    @featureSnapPoints = points
    @featureSnapLocation = location
    @snapExclusions = (featureSnapPoint.feature for featureSnapPoint in points)
    if points.length == 0
      if @featureSnapIndicator?
        @editor.playfield.overlay.removeFeature @featureSnapIndicator
        @featureSnapIndicator = undefined
      return
    unless @featureSnapIndicator?
      @featureSnapIndicator = new Circle()
      @featureSnapIndicator.setStrokeStyle new Style("#000000")
      @featureSnapIndicator.setFillStyle new Style("#00FF00")
      @editor.playfield.overlay.addFeature @featureSnapIndicator
    @featureSnapIndicator.setParameters @editor.playfield.overlay.getLayerPosition(location, @editor.playfield.base), 5
    @featureSnapIndicator.setVisible true


# Base class for property editors.
class PropertyEditor
  constructor: (@editor) ->
    @element = document.createElement "div"

  # Retrieves the value of the specified property if it's the same across all features.  Returns an empty string if
  # features have different values, or the default if the features array is empty.
  getPropertyValue: (features, property, defaultValue = "", subproperty = undefined) ->
    return defaultValue if features.length == 0
    if subproperty?
      value = features[0][property]?[subproperty]
      for index in [1...features.length]
        return "" unless features[index][property]?[subproperty] == value
    else
      value = features[0][property]
      for index in [1...features.length]
        return "" unless features[index][property] == value
    value


# An editor for the properties common to all features.
class FeatureEditor extends PropertyEditor
  constructor: (editor, features = []) ->
    super editor
    @element.innerHTML = "Z-Order: <input id='z-order' type='number' " +
      "value='#{@getPropertyValue(features, 'zOrder', 0)}'></input><br>" +
      "Visible in Game: <select id='visible-in-game'>" +
        "<option value='true'>True</option>" +
        "<option value='false'>False</option>" +
      "</select><br>" +
      "Collidable: <select id='collidable'>" +
        "<option value='true'>True</option>" +
        "<option value='false'>False</option>" +
      "</select><br>" +
      "Reflectivity: <input id='reflectivity' type='number' min='0' step='0.01' " +
        "value='#{@getPropertyValue(features, 'reflectivity', 1)}'></input><br><br>"
    return unless features.length > 0
    $(@element).find("#z-order").change (event) =>
      @editor.perform new SetPropertyAction(features, "zOrder", "setZOrder", Number(event.target.value))
    $(@element).find("#visible-in-game").val String(@getPropertyValue(features, "visibleInGame", false))
    $(@element).find("#visible-in-game").change (event) =>
      @editor.perform new SetPropertyAction(features, "visibleInGame", "setVisibleInGame", event.target.value == "true")
    $(@element).find("#collidable").val String(@getPropertyValue(features, "collidable", false))
    $(@element).find("#collidable").change (event) =>
      @editor.perform new SetPropertyAction(features, "collidable", "setCollidable", event.target.value == "true")
    $(@element).find("#reflectivity").change (event) =>
      @editor.perform new SetPropertyAction(features, "reflectivity", "setReflectivity", Number(event.target.value))
    
  # Applies the property to the specified feature.
  apply: (feature) ->
    feature.setZOrder Number($(@element).find("#z-order").val())
    feature.setVisibleInGame $(@element).find("#visible-in-game").val() == "true"
    feature.setCollidable $(@element).find("#collidable").val() == "true"
    feature.setReflectivity Number($(@element).find("#reflectivity").val())
    
    
# An editor for (fill, stroke) style parameters.
class StyleEditor extends PropertyEditor
  constructor: (editor, prefix = "Stroke", optional = false, defaultNone = false, features = [], propertyPrefix = "stroke") ->
    super editor
    upperPropertyPrefix = propertyPrefix.charAt(0).toUpperCase() + propertyPrefix.slice(1)
    alphaProperty = propertyPrefix + "Alpha"
    alphaPropertySetter = "set" + upperPropertyPrefix + "Alpha"
    @element.innerHTML =
      "#{prefix} Type: <select id='style-type'>" +
        (if optional then "<option value='none'>None</option>" else "") +
        "<option value='color'" + (if optional && !defaultNone then " selected='selected'" else "") + ">Color</option>" +
        "<option value='pattern'>Pattern</option>" +
      "</select><br>" +
      "<div id='style-options'></div>" +
      "Alpha: <input id='alpha' type='number' min='0' max='1' step='0.01' " +
        "value='#{@getPropertyValue(features, alphaProperty, 1)}'></input>"
    unless features.length > 0
      @updateType()  
      $(@element).find("#style-type").change (event) =>
        @updateType()
      return
    @styleProperty = propertyPrefix + "Style"
    @stylePropertySetter = "set" + upperPropertyPrefix + "Style"
    $(@element).find("#style-type").val @getPropertyValue(features, @styleProperty, "", "type")
    @updateType(features)
    $(@element).find("#style-type").change (event) =>
      @updateType()
      @editor.perform new SetPropertyAction(features, @styleProperty, @stylePropertySetter, @getStyle())
    $(@element).find("#alpha").change (event) =>
      @editor.perform new SetPropertyAction(features, alphaProperty, alphaPropertySetter, Number(event.target.value))
  
  # Installs the options for the currently selected type.
  updateType: (features = []) ->
    changer = =>
      @editor.perform new SetPropertyAction(features, @styleProperty, @stylePropertySetter, @getStyle())
    switch $(@element).find("#style-type").val()
      when "none"
        $(@element).find("#style-options").html ""
      when "color"
        $(@element).find("#style-options").html(
          "Color: <input id='color' type='color' value='#{@getPropertyValue(features,
            @styleProperty, "#000000", "style")}'></input>")
        return unless features.length > 0
        $(@element).find("#color").change changer
      when "pattern"
        $(@element).find("#style-options").html(
          "URL: <input id='url' type='text' value='#{@getPropertyValue(features, @styleProperty,
            "/assets/question.png", "url")}'></input><br>" +
          "Repeat Type: <select id='repeat-type'>" +
            "<option value='repeat'>X/Y</option>" +
            "<option value='repeat-x'>X</option>" +
            "<option value='repeat-y'>Y</option>" +
            "<option value='no-repeat'>None</option>" +
          "</select>")
        repeatType = @getPropertyValue(features, @styleProperty, "repeat", "repeatType")
        $(@element).find("#repeat-type").val(if repeatType == "" then "repeat" else repeatType)
        return unless features.length > 0
        $(@element).find("#url").change changer
        $(@element).find("#repeat-type").change changer
  
  # Returns the currently configured style.
  getStyle: ->
    switch $(@element).find("#style-type").val()
      when "none" then new Style(null)
      when "color" then new Style($(@element).find("#color").val())
      when "pattern" then new Pattern($(@element).find("#url").val(), $(@element).find("#repeat-type").val())
  
  # Returns the currently configured alpha value.
  getAlpha: ->
    Number($(@element).find("#alpha").val())
        
        
# An editor for stroke parameters.
class StrokeEditor extends PropertyEditor
  constructor: (editor, optional = false, defaultNone = false, features = []) ->
    super editor
    @element.innerHTML =
      "<br>Line Width: <input id='line-width' type='number' min='1' max='20' " +
        "value='#{@getPropertyValue(features, 'lineWidth', 5)}'></input><br>" +
      "Line Cap: <select id='line-cap'>" +
        "<option value='round'>Round</option>" +
        "<option value='butt'>Butt</option>" +
        "<option value='square'>Square</option>" +
      "</select><br>" +
      "Line Join: <select id='line-join'>" +
        "<option value='round'>Round</option>" +
        "<option value='bevel'>Bevel</option>" +
        "<option value='miter'>Miter</option>" +
      "</select><br>"
    $(@element).prepend (@styleEditor = new StyleEditor(editor, "Stroke", optional, defaultNone, features, "stroke")).element
    return unless features.length > 0
    $(@element).find("#line-width").change (event) =>
      @editor.perform new SetPropertyAction(features, "lineWidth", "setLineWidth", Number(event.target.value))
    $(@element).find("#line-cap").val(@getPropertyValue(features, "lineCap"))    
    $(@element).find("#line-cap").change (event) =>
      @editor.perform new SetPropertyAction(features, "lineCap", "setLineCap", event.target.value)
    $(@element).find("#line-join").val(@getPropertyValue(features, "lineJoin"))
    $(@element).find("#line-join").change (event) =>
      @editor.perform new SetPropertyAction(features, "lineJoin", "setLineJoin", event.target.value)

  # Applies the editor's settings to the specified feature using the given context.
  apply: (feature) ->
    feature.setStrokeStyle @styleEditor.getStyle()
    feature.setStrokeAlpha @styleEditor.getAlpha()
    feature.setLineWidth Number($(@element).find("#line-width").val())
    feature.setLineCap $(@element).find("#line-cap").val()
    feature.setLineJoin $(@element).find("#line-join").val()
  

# Base class for tools that allow drawing features.
class FeatureTool extends Tool
  constructor: (editor, id, name) ->
    super editor, id, name
    $(@options).append (@featureEditor = new FeatureEditor(editor)).element
    
  activate: (temporary = false) ->
    $("#overlay-layer").css "cursor", "crosshair"
    super temporary
  
  deactivate: (temporary = false) ->
    $("#overlay-layer").css "cursor", "default"
    @editor.playfield.overlay.removeFeature(@feature) if @feature?
    @feature = undefined
    super temporary
  
  mousedown: (event) ->
    return unless event.button == 0
    event.preventDefault()
    if @feature
      @transitionPlacementState()
      return
    @editor.setSelection []
    @editor.playfield.overlay.addFeature(@feature = @createFeature())

  mouseleave: (event) ->
    super event
    event.preventDefault()
    @editor.playfield.overlay.removeFeature(@feature) if @feature?
    @feature = undefined
  
  mousemove: (event) ->
    super event
    @adjustFeature() if @feature
      
  mouseup: (event) ->
    return unless event.button == 0
    event.preventDefault()
    @transitionPlacementState() if @feature
    
  # Creates the feature on initial mouse press.
  createFeature: ->

  # Adjusts the feature on mouse movement.
  adjustFeature: ->

  # Switches to the next placement state.
  transitionPlacementState: ->
    @editor.playfield.overlay.removeFeature(@feature)
    @feature.addOrder = undefined # don't use add order from overlay
    @featureEditor.apply @feature
    @maybePlaceFeature()
    @feature = undefined

  # Places the feature (possibly) on mouse release.
  maybePlaceFeature: ->
    

# An editor for line properties.
class LineEditor extends PropertyEditor
  constructor: (editor, features = []) ->
    super editor
    @element.innerHTML = "Role: <select id='role'>" +
        "<option value='none'>None</option>" +
        "<option value='path'>Path</option>" +
        "<option value='starting-line'>Starting Line</option>" +
        "<option value='finish-line'>Finish Line</option>" +
      "</select><br><br>"
    return unless features.length > 0
    $(@element).find("#role").val String(@getPropertyValue(features, "role", "none"))
    $(@element).find("#role").change (event) =>
      @editor.perform new SetPropertyAction(features, "role", "setRole", event.target.value)
    
  # Applies the property to the specified feature.
  apply: (feature) ->
    feature.setRole $(@element).find("#role").val()
    
    
# A tool that allows drawing lines.
class LineTool extends FeatureTool
  constructor: (editor) ->
    super editor, "line", "Line"
    @options.appendChild (@lineEditor = new LineEditor(editor)).element
    @options.appendChild (@strokeEditor = new StrokeEditor(editor)).element
  
  createFeature: ->
    feature = new LineSegment(@snappedPosition, @snappedPosition)
    @lineEditor.apply feature
    @strokeEditor.apply feature
    feature
  
  adjustFeature: ->
    @feature.setEndpoints @feature.start, @snappedPosition
  
  maybePlaceFeature: ->
    return unless @feature.getLength() > 0
    @feature.setEndpoints @editor.playfield.base.getLayerPosition(@feature.start, @editor.playfield.overlay),
      @editor.playfield.base.getLayerPosition(@feature.end, @editor.playfield.overlay)
    @editor.perform new AddRemoveFeaturesAction([ @feature ], [])
    

# A tool that allows drawing arcs.
class ArcTool extends FeatureTool
  constructor: (editor) ->
    super editor, "arc", "Arc"
    @options.appendChild (@strokeEditor = new StrokeEditor(editor)).element

  createFeature: ->
    feature = new Arc(@snappedPosition, 0)
    @strokeEditor.apply feature
    @startAngle = undefined
    feature
  
  adjustFeature: -> 
    if @startAngle?
      angle = Math.atan2(@snappedPosition.y - @feature.center.y, @snappedPosition.x - @feature.center.x)
      oldLength = Arc.getLength(@feature.startAngle, @feature.endAngle)
      newLength = Arc.getLength(@startAngle, angle)
      newLengthComplement = Math.PI * 2 - newLength
      forward = Math.abs(oldLength - newLength)
      reverse = Math.abs(oldLength - newLengthComplement)
      if (if Math.max(forward, reverse) > Math.PI then reverse < forward else @lastReversed)
        @feature.setParameters @feature.center, @feature.radius, angle, @startAngle
        @lastReversed = true
      else
        @feature.setParameters @feature.center, @feature.radius, @startAngle, angle
        @lastReversed = false
    else
      @feature.setParameters @feature.center, @snappedPosition.distance(@feature.center)
      
  transitionPlacementState: ->
    if @startAngle? || @feature.radius == 0
      return super
    @startAngle = Math.atan2(@snappedPosition.y - @feature.center.y, @snappedPosition.x - @feature.center.x)
    @lastReversed = false
    
  maybePlaceFeature: ->
    return unless @feature.radius > 0
    @feature.setParameters @editor.playfield.base.getLayerPosition(@feature.center, @editor.playfield.overlay),
      @editor.playfield.base.getLayerDistance(@feature.radius, @editor.playfield.overlay),
      @feature.startAngle, @feature.endAngle
    @editor.perform new AddRemoveFeaturesAction([ @feature ], [])
    
        
# A tool that allows drawing circles.
class CircleTool extends FeatureTool
  constructor: (editor) ->
    super editor, "circle", "Circle"
    @options.appendChild (@strokeEditor = new StrokeEditor(editor, true, true)).element
    @options.appendChild (@fillStyleEditor = new StyleEditor(editor, "<br>Fill", true, false)).element

  createFeature: ->
    feature = new Circle(@snappedPosition, 0)
    @strokeEditor.apply feature
    feature.setFillStyle @fillStyleEditor.getStyle()
    feature.setFillAlpha @fillStyleEditor.getAlpha()
    feature
  
  adjustFeature: ->
    @feature.setParameters @feature.center, @snappedPosition.distance(@feature.center)
  
  maybePlaceFeature: ->
    return unless @feature.radius > 0
    @feature.setParameters @editor.playfield.base.getLayerPosition(@feature.center, @editor.playfield.overlay),
      @editor.playfield.base.getLayerDistance(@feature.radius, @editor.playfield.overlay)
    @editor.perform new AddRemoveFeaturesAction([ @feature ], [])


# A tool that allows drawing rectangles.
class RectangleTool extends FeatureTool
  constructor: (editor) ->
    super editor, "rectangle", "Rectangle"
    @options.appendChild (@strokeEditor = new StrokeEditor(editor, true, true)).element
    @options.appendChild (@fillStyleEditor = new StyleEditor(editor, "<br>Fill", true, false)).element

  createFeature: ->
    feature = new Polygon([ @snappedPosition, @snappedPosition, @snappedPosition, @snappedPosition ])
    @strokeEditor.apply feature
    feature.setFillStyle @fillStyleEditor.getStyle()
    feature.setFillAlpha @fillStyleEditor.getAlpha()
    feature
  
  adjustFeature: ->
    @feature.setVertices [
      @feature.vertices[0]
      new Point(@snappedPosition.x, @feature.vertices[0].y)
      @snappedPosition
      new Point(@feature.vertices[0].x, @snappedPosition.y)
    ]
  
  maybePlaceFeature: ->
    return if @feature.bounds.isEmpty()
    @feature.setVertices [
      @editor.playfield.base.getLayerPosition(@feature.vertices[0], @editor.playfield.overlay)
      @editor.playfield.base.getLayerPosition(@feature.vertices[1], @editor.playfield.overlay)
      @editor.playfield.base.getLayerPosition(@feature.vertices[2], @editor.playfield.overlay)
      @editor.playfield.base.getLayerPosition(@feature.vertices[3], @editor.playfield.overlay)
    ]
    @editor.perform new AddRemoveFeaturesAction([ @feature ], [])
    

# An editor for image properties.
class ImageEditor extends PropertyEditor
  constructor: (editor, features = []) ->
    super editor
    @element.innerHTML = "Role: <select id='role'>" +
      "<option value='none'>None</option>" +
      "<option value='wikipedia-prompt'>Wikipedia Prompt</option>" +
      "<option value='reddit-prompt'>Reddit Prompt</option>" +
      "<option value='boost'>Boost</option>" +
      "<option value='omniboost'>Omniboost</option>" +
      "</select><br><br>" +
      "URL: <input id='url' type='text'></input><br>" +
      "Alpha: <input id='alpha' type='number' " +
      "value='#{@getPropertyValue(features, 'alpha', 1)}'></input><br><br>"
    return unless features.length > 0
    $(@element).find("#url").val @getPropertyValue(features, "url")
    $(@element).find("#url").change (event) =>
      @editor.perform new SetPropertyAction(features, "url", "setURL", event.target.value)
    $(@element).find("#alpha").change (event) =>
      @editor.perform new SetPropertyAction(features, "alpha", "setAlpha", Number(event.target.value))
    $(@element).find("#role").val String(@getPropertyValue(features, "role", "none"))
    $(@element).find("#role").change (event) =>
      @editor.perform new SetPropertyAction(features, "role", "setRole", event.target.value)
      
  # Applies the property to the specified feature.
  apply: (feature) ->
    feature.setURL $(@element).find("#url").val()
    feature.setAlpha Number($(@element).find("#alpha").val())
    feature.setRole $(@element).find("#role").val()
    
    
# A tool that allows placing images.
class ImageTool extends FeatureTool
  constructor: (editor) ->
    super editor, "image", "Image"
    @options.appendChild (@imageEditor = new ImageEditor(editor)).element
    $(@options).append "Rotation: <input id='rotation' type='number' value='0'></input>"

  createFeature: ->
    feature = new ImageFeature(@snappedPosition, @getRotation())
    @imageEditor.apply feature
    feature
  
  adjustFeature: ->
    @feature.setPosition @snappedPosition, @getRotation()
  
  # Returns the currently set rotation value.
  getRotation: ->
    Number($(@options).find("#rotation").val()) * Math.PI / 180
  
  maybePlaceFeature: ->
    @feature.setPosition @editor.playfield.base.getLayerPosition(@feature.translation, @editor.playfield.overlay),
      @feature.rotation
    @editor.perform new AddRemoveFeaturesAction([ @feature ], [])


# An editor for text properties.
class TextEditor extends PropertyEditor
  constructor: (editor, features = []) ->
    super editor
    @element.innerHTML = "<br>Text: <input id='text' type='text'></input><br>" +
      "Font Size: <input id='font-size' min='8' max='100' " +
        "value='#{@getPropertyValue(features, 'fontSize', 20)}'></input><br>" +
      "Font Family: <select id='font-family'>" +
        "<option value='sans-serif'>Sans-Serif</option>" +
        "<option value='serif'>Serif</option>" +
        "<option value='monospace'>Monospace</option>" +
      "</select><br><br>"
    return unless features.length > 0 
    $(@element).find("#text").val @getPropertyValue(features, "text")
    $(@element).find("#text").change (event) =>
      @editor.perform new SetPropertyAction(features, "text", "setText", event.target.value)
    $(@element).find("#font-size").change (event) =>
      @editor.perform new SetPropertyAction(features, "fontSize", "setFontSize", Number(event.target.value))
    $(@element).find("#font-family").val(@getPropertyValue(features, "fontFamily"))
    $(@element).find("#font-family").change (event) =>
      @editor.perform new SetPropertyAction(features, "fontFamily", "setFontFamily", event.target.value)
      
  # Applies the property to the specified feature.
  apply: (feature) ->
    feature.setText $(@element).find("#text").val()
    feature.setFontSize Number($(@element).find("#font-size").val())
    feature.setFontFamily $(@element).find("#font-family").val()
    
    
# A tool that allows placing text.
class TextTool extends FeatureTool
  constructor: (editor) ->
    super editor, "text", "Text"
    @options.appendChild (@strokeEditor = new StrokeEditor(editor, true, true)).element
    @options.appendChild (@fillStyleEditor = new StyleEditor(editor, "<br>Fill", true, false)).element
    @options.appendChild (@textEditor = new TextEditor(editor)).element
    $(@options).append "Rotation: <input id='rotation' type='number' value='0'></input>"

  createFeature: ->
    feature = new TextFeature(@snappedPosition, @getRotation())
    @strokeEditor.apply feature
    feature.setFillStyle @fillStyleEditor.getStyle()
    feature.setFillAlpha @fillStyleEditor.getAlpha()
    @textEditor.apply feature
    feature
  
  adjustFeature: ->
    @feature.setPosition @snappedPosition, @getRotation()
  
  # Returns the currently set rotation value.
  getRotation: ->
    Number($(@options).find("#rotation").val()) * Math.PI / 180
  
  maybePlaceFeature: ->
    @feature.setPosition @editor.playfield.base.getLayerPosition(@feature.translation, @editor.playfield.overlay),
      @feature.rotation
    @editor.perform new AddRemoveFeaturesAction([ @feature ], [])


# A tool that allows placing path segments.
class PathTool extends Tool
  constructor: (editor) ->
    super editor, "path", "Path"
    @options.appendChild (@strokeEditor = new StrokeEditor(editor)).element
    $(@options).append "<br>Path Width: <input id='path-width' type='number' value='300' min='0'></input><br>" +
      "Cap Length: <input id='cap-length' type='number' value='120' min='0'></input><br>" +
      "Path Join: <select id='path-join'>" +
      "<option value='round'>Round</option>" +
      "<option value='bevel'>Bevel</option>" +
      "<option value='miter'>Miter</option>" +
      "</select>"
    @options.appendChild (@fillStyleEditor = new StyleEditor(editor, "<br>Fill", true, true)).element
    $(@options).append "<br><button id='compute-length'>Compute Length:</button> <span id='path-length'></span>"
    $(@options).find("#compute-length").click =>
      path = @editor.playfield.buildPath()
      length = 0
      if path.length >= 2
        for index in [0...path.length - 1]
          length += path[index][0].distance(path[index + 1][0])
      $(@options).find("#path-length").html "#{Math.round(length)} (#{path.length} nodes)"
    @features = []
    @oldConnectedFeatures = []
    @newConnectedFeatures = []
    
  activate: (temporary = false) ->
    $("#overlay-layer").css "cursor", "crosshair"
    super temporary
  
  deactivate: (temporary = false) ->
    $("#overlay-layer").css "cursor", "default"
    @editor.playfield.overlay.removeFeatures(@features)
    @editor.playfield.base.addFeatures(@oldConnectedFeatures)
    @editor.playfield.overlay.removeFeatures(@newConnectedFeatures)
    @features = []
    @oldConnectedFeatures = []
    @newConnectedFeatures = []
    super temporary
  
  mousedown: (event) ->
    return unless event.button == 0
    event.preventDefault()
    @editor.setSelection []
    join = $(@options).find("#path-join").val()
    fillStyle = @fillStyleEditor.getStyle()
    for feature in @editor.playfield.base.getFeaturesIntersectingCircle(@snappedPosition, Tool.SNAP_RADIUS)
      if feature.constructor == LineSegment && feature.role == "path" && feature.features?
        @oldConnectedFeatures = feature.features
        reversed = feature.start.distance(@snappedPosition) < feature.end.distance(@snappedPosition)
        @editor.playfield.base.removeFeatures(@oldConnectedFeatures)
        @newConnectedFeatures = [ @oldConnectedFeatures[LineSegment.PATH_INDEX].clone(undefined, reversed),
          @oldConnectedFeatures[if reversed then LineSegment.RIGHT_INDEX else
            LineSegment.LEFT_INDEX].clone(undefined, reversed),
          @oldConnectedFeatures[if reversed then LineSegment.LEFT_INDEX else
            LineSegment.RIGHT_INDEX].clone(undefined, reversed),
          @oldConnectedFeatures[if reversed then LineSegment.TOP_INDEX else
            LineSegment.BOTTOM_INDEX].clone() ]
        @newConnectedFeatures[LineSegment.TOP_INDEX] = (if join == "round" then new Arc(@snappedPosition) else
          new LineSegment(@snappedPosition, @snappedPosition))
        @strokeEditor.apply @newConnectedFeatures[LineSegment.TOP_INDEX]
        if @oldConnectedFeatures[LineSegment.START_INDEX]? &&
            !@oldConnectedFeatures[LineSegment.START_INDEX].intersectsCircle(@snappedPosition, Tool.SNAP_RADIUS)
          @newConnectedFeatures[LineSegment.START_INDEX] = @oldConnectedFeatures[LineSegment.START_INDEX].clone()
        if @oldConnectedFeatures[LineSegment.FINISH_INDEX]? &&
            !@oldConnectedFeatures[LineSegment.FINISH_INDEX].intersectsCircle(@snappedPosition, Tool.SNAP_RADIUS)
          @newConnectedFeatures[LineSegment.FINISH_INDEX] = @oldConnectedFeatures[LineSegment.FINISH_INDEX].clone()
          @newConnectedFeatures[LineSegment.FINISH_AREA_INDEX] = @oldConnectedFeatures[LineSegment.FINISH_AREA_INDEX].clone()
        if @oldConnectedFeatures[LineSegment.PATH_BACKGROUND_INDEX]?
          @newConnectedFeatures[LineSegment.PATH_BACKGROUND_INDEX] =
            @oldConnectedFeatures[LineSegment.PATH_BACKGROUND_INDEX].clone()
        if @oldConnectedFeatures[LineSegment.BOTTOM_BACKGROUND_INDEX]?
          @newConnectedFeatures[LineSegment.BOTTOM_BACKGROUND_INDEX] =
            @oldConnectedFeatures[LineSegment.BOTTOM_BACKGROUND_INDEX].clone()
        @newConnectedFeatures[LineSegment.PATH_INDEX].features = @newConnectedFeatures
        @editor.playfield.overlay.addFeatures(@newConnectedFeatures)
        break
    feature = new LineSegment(@snappedPosition, @snappedPosition)
    @strokeEditor.apply feature
    feature.setStrokeStyle new Style("#FF0000")
    feature.setCollidable false
    feature.setVisibleInGame false
    feature.setRole "path"
    @features[LineSegment.PATH_INDEX] = feature
    feature = new LineSegment(@snappedPosition, @snappedPosition)
    @strokeEditor.apply feature
    @features[LineSegment.LEFT_INDEX] = feature
    feature = new LineSegment(@snappedPosition, @snappedPosition)
    @strokeEditor.apply feature
    @features[LineSegment.RIGHT_INDEX] = feature
    feature = (if @oldConnectedFeatures.length > 0 && join == "round" then new Arc(@snappedPosition) else
      new LineSegment(@snappedPosition, @snappedPosition))
    @strokeEditor.apply feature
    @features[LineSegment.BOTTOM_INDEX] = feature
    feature = new LineSegment(@snappedPosition, @snappedPosition)
    @strokeEditor.apply feature
    @features[LineSegment.TOP_INDEX] = feature
    unless @oldConnectedFeatures.length > 0 && @oldConnectedFeatures[LineSegment.PATH_INDEX].isOnFeature(
        @snappedPosition, Tool.SNAP_RADIUS, "finish-line")
      feature = new LineSegment(@snappedPosition, @snappedPosition)
      @strokeEditor.apply feature
      feature.setStrokeStyle new Style("#FF0000")
      feature.setCollidable false
      feature.setVisibleInGame false
      feature.setRole "starting-line"
      @features[LineSegment.START_INDEX] = feature
    unless @oldConnectedFeatures.length > 0 && @oldConnectedFeatures[LineSegment.PATH_INDEX].isOnFeature(
        @snappedPosition, Tool.SNAP_RADIUS, "starting-line")
      feature = new LineSegment(@snappedPosition, @snappedPosition)
      @strokeEditor.apply feature
      feature.setStrokeStyle new Style("#FF0000")
      feature.setVisibleInGame false
      feature.setReflectivity 0
      feature.setRole "finish-line"
      @features[LineSegment.FINISH_INDEX] = feature
      feature = new Polygon([ @snappedPosition, @snappedPosition, @snappedPosition, @snappedPosition ])
      feature.setStrokeStyle new Style(null)
      feature.setFillStyle new Pattern("/assets/checkers.png")
      feature.setZOrder -1
      feature.setCollidable false
      @features[LineSegment.FINISH_AREA_INDEX] = feature
    if fillStyle.style?
      feature = new Polygon([ @snappedPosition, @snappedPosition, @snappedPosition, @snappedPosition ])
      feature.setStrokeStyle fillStyle
      feature.setStrokeAlpha @fillStyleEditor.getAlpha()
      feature.setFillStyle fillStyle
      feature.setFillAlpha @fillStyleEditor.getAlpha()
      feature.setZOrder -2
      feature.setCollidable false
      @features[LineSegment.PATH_BACKGROUND_INDEX] = feature
      if @oldConnectedFeatures.length > 0 && join == "round"
        feature = new Circle(@snappedPosition, 0)
        feature.setStrokeStyle new Style(null)
        feature.setFillStyle fillStyle
        feature.setFillAlpha @fillStyleEditor.getAlpha()
        feature.setZOrder -2
        feature.setCollidable false
        @features[LineSegment.BOTTOM_BACKGROUND_INDEX] = feature
    @editor.playfield.overlay.addFeatures(@features)
    @features[LineSegment.PATH_INDEX].features = @features
    
  mouseleave: (event) ->
    super event
    event.preventDefault()
    @editor.playfield.overlay.removeFeatures(@features)
    @editor.playfield.base.addFeatures(@oldConnectedFeatures)
    @editor.playfield.overlay.removeFeatures(@newConnectedFeatures)
    @features = []
    @oldConnectedFeatures = []
    @newConnectedFeatures = []
  
  mousemove: (event) ->
    super event
    return if @features.length == 0
    @features[LineSegment.PATH_INDEX].setEndpoints @features[0].start, @snappedPosition
    length = @features[LineSegment.PATH_INDEX].getLength()
    width = Number($(@options).find("#path-width").val()) / 2
    capLength = Number($(@options).find("#cap-length").val())
    join = $(@options).find("#path-join").val()
    [ ox, oy, cx, cy ] = [ width, 0, 0, capLength ]
    if length > 0    
      ox = width * (@features[LineSegment.PATH_INDEX].start.y - @snappedPosition.y) / length
      oy = width * (@snappedPosition.x - @features[LineSegment.PATH_INDEX].start.x) / length
      cx = capLength * (@snappedPosition.x - @features[LineSegment.PATH_INDEX].start.x) / length
      cy = capLength * (@snappedPosition.y - @features[LineSegment.PATH_INDEX].start.y) / length
    @features[LineSegment.LEFT_INDEX].setEndpoints @features[LineSegment.PATH_INDEX].start.translated(-ox - cx, -oy - cy),
      @snappedPosition.translated(-ox + cx, -oy + cy)
    @features[LineSegment.RIGHT_INDEX].setEndpoints @features[LineSegment.PATH_INDEX].start.translated(ox - cx, oy - cy),
      @snappedPosition.translated(ox + cx, oy + cy)
    if @oldConnectedFeatures.length > 0
      direction = (@newConnectedFeatures[LineSegment.PATH_INDEX].end.x -
        @newConnectedFeatures[LineSegment.PATH_INDEX].start.x) * (@snappedPosition.y -
          @features[LineSegment.PATH_INDEX].start.y) - (@newConnectedFeatures[LineSegment.PATH_INDEX].end.y -
            @newConnectedFeatures[LineSegment.PATH_INDEX].start.y) * (@snappedPosition.x -
              @features[LineSegment.PATH_INDEX].start.x)
      isect = LineSegment.getLineLineIntersection(@newConnectedFeatures[LineSegment.LEFT_INDEX].start,
        @newConnectedFeatures[LineSegment.LEFT_INDEX].end, @features[LineSegment.LEFT_INDEX].start,
          @features[LineSegment.LEFT_INDEX].end) ? @features[LineSegment.LEFT_INDEX].start
      if join == "round" && direction > 0
        startAngle = Math.atan2(@newConnectedFeatures[LineSegment.LEFT_INDEX].start.x -
          @newConnectedFeatures[LineSegment.LEFT_INDEX].end.x, @newConnectedFeatures[LineSegment.LEFT_INDEX].end.y -
            @newConnectedFeatures[LineSegment.LEFT_INDEX].start.y)
        endAngle = Math.atan2(@features[LineSegment.LEFT_INDEX].start.x - @features[LineSegment.LEFT_INDEX].end.x,
          @features[LineSegment.LEFT_INDEX].end.y - @features[LineSegment.LEFT_INDEX].start.y)
        center = @features[LineSegment.PATH_INDEX].start
        right = center.translated(width, 0)
        @newConnectedFeatures[LineSegment.LEFT_INDEX].setEndpoints @newConnectedFeatures[LineSegment.LEFT_INDEX].start,
          right.rotated(center.x, center.y, startAngle)
        @features[LineSegment.LEFT_INDEX].setEndpoints right.rotated(center.x, center.y, endAngle),
          @features[LineSegment.LEFT_INDEX].end
        @newConnectedFeatures[LineSegment.TOP_INDEX].setParameters center, width, startAngle, endAngle
      else if join == "bevel" && isect.distance(@features[LineSegment.PATH_INDEX].start) > width && direction > 0
        delta = isect.subtracted(@features[LineSegment.PATH_INDEX].start).normalize().scale(width)
        start = @features[LineSegment.PATH_INDEX].start.translated(delta.x, delta.y)
        end = start.translated(-delta.y, delta.x)
        first = LineSegment.getLineLineIntersection(@newConnectedFeatures[LineSegment.LEFT_INDEX].start,
          @newConnectedFeatures[LineSegment.LEFT_INDEX].end, start, end)
        @newConnectedFeatures[LineSegment.LEFT_INDEX].setEndpoints @newConnectedFeatures[LineSegment.LEFT_INDEX].start, first
        second = LineSegment.getLineLineIntersection(@features[LineSegment.LEFT_INDEX].start,
          @features[LineSegment.LEFT_INDEX].end, start, end)
        @features[LineSegment.LEFT_INDEX].setEndpoints second, @features[LineSegment.LEFT_INDEX].end
        @newConnectedFeatures[LineSegment.TOP_INDEX].setEndpoints first, second
      else
        @newConnectedFeatures[LineSegment.LEFT_INDEX].setEndpoints @newConnectedFeatures[LineSegment.LEFT_INDEX].start, isect
        @features[LineSegment.LEFT_INDEX].setEndpoints isect, @features[LineSegment.LEFT_INDEX].end
        if join == "round"
          @newConnectedFeatures[LineSegment.TOP_INDEX].setParameters isect, 0
        else
          @newConnectedFeatures[LineSegment.TOP_INDEX].setEndpoints isect, isect
      isect = LineSegment.getLineLineIntersection(@newConnectedFeatures[LineSegment.RIGHT_INDEX].start,
        @newConnectedFeatures[LineSegment.RIGHT_INDEX].end, @features[LineSegment.RIGHT_INDEX].start,
          @features[LineSegment.RIGHT_INDEX].end) ? @features[LineSegment.RIGHT_INDEX].start
      if join == "round" && direction < 0
        startAngle = Math.atan2(@features[LineSegment.RIGHT_INDEX].end.x - @features[LineSegment.RIGHT_INDEX].start.x,
          @features[LineSegment.RIGHT_INDEX].start.y - @features[LineSegment.RIGHT_INDEX].end.y)
        endAngle = Math.atan2(@newConnectedFeatures[LineSegment.RIGHT_INDEX].end.x -
          @newConnectedFeatures[LineSegment.RIGHT_INDEX].start.x, @newConnectedFeatures[LineSegment.RIGHT_INDEX].start.y -
            @newConnectedFeatures[LineSegment.RIGHT_INDEX].end.y)
        center = @features[LineSegment.PATH_INDEX].start
        right = center.translated(width, 0)
        @newConnectedFeatures[LineSegment.RIGHT_INDEX].setEndpoints @newConnectedFeatures[LineSegment.RIGHT_INDEX].start,
          right.rotated(center.x, center.y, endAngle)
        @features[LineSegment.RIGHT_INDEX].setEndpoints right.rotated(center.x, center.y, startAngle),
          @features[LineSegment.RIGHT_INDEX].end
        @features[LineSegment.BOTTOM_INDEX].setParameters center, width, startAngle, endAngle
      else if join == "bevel" && isect.distance(@features[LineSegment.PATH_INDEX].start) > width && direction < 0
        delta = isect.subtracted(@features[LineSegment.PATH_INDEX].start).normalize().scale(width)
        start = @features[LineSegment.PATH_INDEX].start.translated(delta.x, delta.y)
        end = start.translated(-delta.y, delta.x)
        first = LineSegment.getLineLineIntersection(@newConnectedFeatures[LineSegment.RIGHT_INDEX].start,
          @newConnectedFeatures[LineSegment.RIGHT_INDEX].end, start, end)
        @newConnectedFeatures[LineSegment.RIGHT_INDEX].setEndpoints @newConnectedFeatures[LineSegment.RIGHT_INDEX].start, first
        second = LineSegment.getLineLineIntersection(@features[LineSegment.RIGHT_INDEX].start,
          @features[LineSegment.RIGHT_INDEX].end, start, end)
        @features[LineSegment.RIGHT_INDEX].setEndpoints second, @features[LineSegment.RIGHT_INDEX].end
        @features[LineSegment.BOTTOM_INDEX].setEndpoints first, second
      else
        @newConnectedFeatures[LineSegment.RIGHT_INDEX].setEndpoints @newConnectedFeatures[LineSegment.RIGHT_INDEX].start, isect
        @features[LineSegment.RIGHT_INDEX].setEndpoints isect, @features[LineSegment.RIGHT_INDEX].end
        if join == "round"
          @features[LineSegment.BOTTOM_INDEX].setParameters isect, 0
        else
          @features[LineSegment.BOTTOM_INDEX].setEndpoints isect, isect
      if @newConnectedFeatures[LineSegment.PATH_BACKGROUND_INDEX]?
        vertices = @newConnectedFeatures[LineSegment.PATH_BACKGROUND_INDEX].vertices[...]
        vertices[0] = @newConnectedFeatures[LineSegment.LEFT_INDEX].start
        vertices[1] = @newConnectedFeatures[LineSegment.LEFT_INDEX].end
        vertices[2] = @newConnectedFeatures[LineSegment.RIGHT_INDEX].end
        vertices[3] = @newConnectedFeatures[LineSegment.RIGHT_INDEX].start
        @newConnectedFeatures[LineSegment.PATH_BACKGROUND_INDEX].setVertices vertices
      if @features[LineSegment.PATH_BACKGROUND_INDEX]?
        @features[LineSegment.PATH_BACKGROUND_INDEX].setVertices [
          @features[LineSegment.LEFT_INDEX].start
          @features[LineSegment.LEFT_INDEX].end
          @features[LineSegment.RIGHT_INDEX].end
          @features[LineSegment.RIGHT_INDEX].start
          @newConnectedFeatures[LineSegment.RIGHT_INDEX].end
          @newConnectedFeatures[LineSegment.LEFT_INDEX].end
        ]
      if @features[LineSegment.BOTTOM_BACKGROUND_INDEX]?
        @features[LineSegment.BOTTOM_BACKGROUND_INDEX].setParameters @features[LineSegment.PATH_INDEX].start, width
    else
      @features[LineSegment.BOTTOM_INDEX].setEndpoints @features[LineSegment.PATH_INDEX].start.translated(-ox - cx, -oy - cy),
        @features[LineSegment.PATH_INDEX].start.translated(ox - cx, oy - cy)
      if @features[LineSegment.PATH_BACKGROUND_INDEX]?
        @features[LineSegment.PATH_BACKGROUND_INDEX].setVertices [
          @features[LineSegment.LEFT_INDEX].start
          @features[LineSegment.LEFT_INDEX].end
          @features[LineSegment.RIGHT_INDEX].end
          @features[LineSegment.RIGHT_INDEX].start
        ]
    @features[LineSegment.TOP_INDEX].setEndpoints @snappedPosition.translated(-ox + cx, -oy + cy),
      @snappedPosition.translated(ox + cx, oy + cy)
    if @features[LineSegment.START_INDEX]? && @features[LineSegment.FINISH_INDEX]?
      @features[LineSegment.START_INDEX].setEndpoints @features[LineSegment.PATH_INDEX].start.translated(-ox, -oy),
        @features[LineSegment.PATH_INDEX].start.translated(ox, oy)
      @features[LineSegment.FINISH_INDEX].setEndpoints @snappedPosition.translated(-ox, -oy),
        @snappedPosition.translated(ox, oy)
    else
      line = @features[LineSegment.START_INDEX] ? @features[LineSegment.FINISH_INDEX]
      line.setEndpoints @snappedPosition.translated(-ox, -oy), @snappedPosition.translated(ox, oy) if line?
    if @features[LineSegment.FINISH_INDEX]?
      @features[LineSegment.FINISH_AREA_INDEX].setVertices [
        @features[LineSegment.LEFT_INDEX].end
        @features[LineSegment.RIGHT_INDEX].end
        @features[LineSegment.FINISH_INDEX].end
        @features[LineSegment.FINISH_INDEX].start
      ]
    
  mouseup: (event) ->
    return unless event.button == 0
    event.preventDefault()
    return if @features.length == 0
    for feature in @features
      if feature?
        @editor.playfield.overlay.removeFeature feature
        feature.addOrder = undefined # don't use add order from overlay
    for feature in @newConnectedFeatures
      if feature?
        @editor.playfield.overlay.removeFeature feature
        feature.addOrder = undefined
    if @features[LineSegment.PATH_INDEX].getLength() > 0
      @editor.perform new AddRemoveFeaturesAction(@features.concat(@newConnectedFeatures), @oldConnectedFeatures)
    else
      @editor.playfield.base.addFeatures(@oldConnectedFeatures)
    @features = []
    @oldConnectedFeatures = []
    @newConnectedFeatures = []
        
        
# A tool that allows a limited amount of game-like testing.
class TestTool extends Tool
  constructor: (editor) ->
    super editor, "test", "Test"
    @snap = false
    @allowsTemporaryTools = false
    @pucks = {}
    for color in Puck.COLORS
      do (color) =>
        upperColor = color.charAt(0).toUpperCase() + color.slice(1)
        $(@options).append "<button id='#{color}-puck'></button><br>"
        $(@options).find("##{color}-puck").click =>
          puck = @pucks[color]
          if puck?
            puck.removeAll()
            delete @pucks[color]
            @updateButtonLabel color
            @lastPuckPlaced = undefined if puck == @lastPuckPlaced
          else
            if @placingPuck?
              @editor.playfield.overlay.removeFeature @placingPuck
            @editor.playfield.setGameModeEnabled false
            @placingPuck = new Puck(@editor.playfield, new Point(), color)
            @placingPuck.setVisible false
            @editor.playfield.overlay.addFeature @placingPuck
    $(@options).append "<br>Action: <select id='action'>" +
      "<option value='pause'>Pause</option>" +
      "<option value='pull'>Pull</option>" +
      "</select><button id='add-action'>Add</button><br>"
    $(@options).find("#add-action").click (event) =>
      return unless @lastPuckPlaced?
      switch $(@options).find("#action").val()
        when "pause" then @lastPuckPlaced.addAction(new Pause())
        when "pull" then @lastPuckPlaced.addAction(new Pull())
    $(@options).append "<br><button id='go'>Go!</button>"  
    $(@options).find("#go").click (event) =>
      event.target.disabled = true
      @editor.playfield.simulate (puck for own key, puck of @pucks), 1, =>
        event.target.disabled = false
    
  activate: (temporary = false) ->
    @editor.setSelection []
    @editor.playfield.setGameModeEnabled true
    @updateButtonLabel(color) for color in Puck.COLORS
    super temporary
  
  deactivate: (temporary = false) ->
    @editor.playfield.setGameModeEnabled false
    for own key, puck of @pucks
      puck.removeAll()
    @pucks = {}
    if @placingPuck?
      @editor.playfield.overlay.removeFeature @placingPuck
      @placingPuck = undefined
    super temporary
  
  mousedown: (event) ->
    return unless @placingPuck && event.button == 0
    @editor.playfield.setGameModeEnabled true
    @editor.playfield.overlay.removeFeature @placingPuck
    @placingPuck.setPosition @editor.playfield.base.getLayerPosition(@placingPuck.translation, @editor.playfield.overlay)
    @editor.playfield.base.addFeature @placingPuck
    @pucks[@placingPuck.color] = @placingPuck
    @updateButtonLabel @placingPuck.color
    @lastPuckPlaced = @placingPuck
    @placingPuck = undefined
  
  # Updates the label for the specified color button.
  updateButtonLabel: (color) ->
    upperColor = color.charAt(0).toUpperCase() + color.slice(1)
    if @pucks[color]?
      $(@options).find("##{color}-puck").text "Remove #{upperColor} Puck"
    else
      $(@options).find("##{color}-puck").text "Place #{upperColor} Puck"
  
  mouseenter: (event) ->
    super event
    return unless @placingPuck?
    @placingPuck.setPosition @snappedPosition
    @placingPuck.setVisible true
  
  mouseleave: (event) ->
    super event
    return unless @placingPuck?
    @placingPuck.setVisible false
    
  mousemove: (event) ->
    super event
    return unless @placingPuck?
    @placingPuck.setPosition @snappedPosition
  
    
# The top-level track editor class.
class TrackEditor
  # The maximum number of undoable actions to store.
  @UNDO_LIMIT: 1000

  # The color of selected features.
  @SELECTION_COLOR: "#00FF00"

  constructor: ->
    @playfield = new Playfield(false)
    @undoStack = []
    @redoStack = []
    @selection = []
    @clipboard = []
    
    # set up the grid and controls
    $("#undo").click => @undoLast()
    $("#redo").click => @redoNext()
    $("#cut").click => @cutSelection()
    $("#copy").click => @copySelection()
    $("#paste").click => @pasteSelection()
    $("#delete").click => @deleteSelection()
    
    # these don't get reset unless we do a "full" refresh
    $("#undo").get(0).disabled = true
    $("#redo").get(0).disabled = true
    $("#cut").get(0).disabled = true
    $("#copy").get(0).disabled = true
    $("#paste").get(0).disabled = true
    $("#delete").get(0).disabled = true
    
    # create the tools and wire up the selector
    @tools = [
      @selectedTool = @panGlobalsTool = new PanGlobalsTool(this)
      @selectTool = new SelectTool(this)
      new LineTool(this)
      new ArcTool(this)
      new CircleTool(this)
      new RectangleTool(this)
      new ImageTool(this)
      new TextTool(this)
      new PathTool(this)
      new AdjustTool(this)
      new EraseTool(this)
      new TestTool(this)
    ]
    @selectedTool.activate()
    $("#tool").change (event) =>
      @setSelectedTool @tools[event.target.selectedIndex]
      
    # forward mouse, key events to the active tool
    @shiftDown = false
    @ctrlDown = false
    @mouseIn = false
    @mouseClientX = @mouseClientY = 0
    @actionGroup = 0
    $("#overlay-layer")
      .click (event) => @selectedTool.click event
      .mousedown (event) =>
        @actionGroup++ if event.button == 0
        @selectedTool.mousedown event
      .mouseup (event) => @selectedTool.mouseup event
      .mouseenter (event) =>
        @mouseClientX = event.clientX
        @mouseClientY = event.clientY
        @mouseIn = true
        if event.ctrlKey
          @ctrlDown = true
        if event.shiftKey
          @shiftDown = true
          @updateTemporaryTool()
        @selectedTool.mouseenter event
      .mouseleave (event) =>
        @mouseIn = false
        if @ctrlDown
          @ctrlDown = false
        if @shiftDown
          @shiftDown = false
          @updateTemporaryTool()
        @selectedTool.mouseleave event
      .mousemove (event) =>
        @mouseClientX = event.clientX
        @mouseClientY = event.clientY
        @selectedTool.mousemove event
   
    $(document)
      .keydown (event) =>
        if event.ctrlKey
          if @isZKey(event)
            if event.shiftKey then @redoNext() else @undoLast() 
            return
          else if @isXKey(event)
            @cutSelection()
            return
          else if @isCKey(event)
            @copySelection()
            return
          else if @isVKey(event)
            @pasteSelection()
            return
        if @isDeleteKey(event)
          @deleteSelection()
          return
        return unless @mouseIn
        if @isShiftKey(event) && !@shiftDown
          @shiftDown = true
          @updateTemporaryTool()
        else if @isCtrlKey(event) && !@ctrlDown
          @ctrlDown = true
          @updateTemporaryTool()
        else
          @selectedTool.keydown event
      .keyup (event) =>
        return unless @mouseIn
        if @isShiftKey(event) && @shiftDown
          @shiftDown = false
          @updateTemporaryTool()
        else if @isCtrlKey(event) && @ctrlDown
          @ctrlDown = false
          @updateTemporaryTool()
        else
          @selectedTool.keyup event
    
  # Updates the temporarily active tool based on the mouse/key state.
  updateTemporaryTool: ->
    if @shiftDown && @mouseIn && @selectedTool.allowsTemporaryTools
      @setSelectedTool (if @ctrlDown then @selectTool else @panGlobalsTool), true
    else @setSelectedTool @tools[$("#tool").get(0).selectedIndex], true
  
  # Makes the current temporary tool permanent.
  makeTemporaryToolPermanent: ->
    tool = @selectedTool
    @setSelectedTool @tools[$("#tool").get(0).selectedIndex], true
    $("#tool").val(tool.id)
    @setSelectedTool tool
  
  # Checks whether the key event provided represents the shift key.
  isShiftKey: (event) ->
    event.key? && event.key == "Shift" || event.which? && event.which == 16 || event.keyCode == 16
  
  # Checks whether the key event provided represents the control key.
  isCtrlKey: (event) ->
    event.key? && event.key == "Control" || event.which? && event.which == 17 || event.keyCode == 17
  
  # Checks whether the key event provided represents the Z key.
  isZKey: (event) ->
    event.key? && (event.key == "z" || event.key == "Z") || event.which? && event.which == 90 || event.keyCode == 90
  
  # Checks whether the key event provided represents the Z key.
  isXKey: (event) ->
    event.key? && (event.key == "x" || event.key == "X") || event.which? && event.which == 88 || event.keyCode == 88
  
  # Checks whether the key event provided represents the Z key.
  isCKey: (event) ->
    event.key? && (event.key == "c" || event.key == "C") || event.which? && event.which == 67 || event.keyCode == 67
  
  # Checks whether the key event provided represents the Z key.
  isVKey: (event) ->
    event.key? && (event.key == "v" || event.key == "V") || event.which? && event.which == 86 || event.keyCode == 86
  
  # Checks whether the key event provided represents the delete key.
  isDeleteKey: (event) ->
    event.key? && event.key == "Delete" || event.which? && event.which == 46 || event.keyCode == 46
    
  # Notes that the playfield has changed.
  playfieldChanged: ->
    @setSelection []
    @simulateMouseMove()
    
  # Selects the tool specified.
  setSelectedTool: (tool, temporary = false) ->
    return if @selectedTool == tool
    @selectedTool.deactivate temporary 
    @selectedTool = tool
    @selectedTool.activate temporary

  # Sets the selection to the specified features.
  setSelection: (selection) ->
    for feature in @selection
      feature.setHighlightColor(undefined) if selection.indexOf(feature) == -1
    for feature in selection
      feature.setHighlightColor(TrackEditor.SELECTION_COLOR) if @selection.indexOf(feature) == -1
    @selection = selection
    $("#cut").get(0).disabled = (@selection.length == 0)
    $("#copy").get(0).disabled = (@selection.length == 0)
    $("#delete").get(0).disabled = (@selection.length == 0)
    @selectTool.selectionChanged()
    
  # Simulates a mouse move event in order to get the selected tool to update its display.
  simulateMouseMove: ->
    setTimeout((=> @selectedTool.mousemove({ clientX: @mouseClientX, clientY: @mouseClientY }) if @mouseIn), 0)
    
  # Adds an action to the undo stack and performs it.
  perform: (action) ->
    unless @undoStack.length > 0 && @undoStack[@undoStack.length - 1].maybeMerge(action)
      @undoStack.push action
      @undoStack.shift() if @undoStack.length > TrackEditor.UNDO_LIMIT
    action.perform(this)
    @redoStack = []
    $("#undo").get(0).disabled = false
    $("#redo").get(0).disabled = true

  # Undoes the last action on the undo stack.
  undoLast: ->
    return if @undoStack.length == 0
    action = @undoStack.pop()
    action.reverse(this)
    @redoStack.push(action)
    $("#undo").get(0).disabled = (@undoStack.length == 0)
    $("#redo").get(0).disabled = false

  # Redoes the next action on the redo stack.
  redoNext: ->
    return if @redoStack.length == 0
    action = @redoStack.pop()
    action.perform(this)
    @undoStack.push(action)
    $("#undo").get(0).disabled = false
    $("#redo").get(0).disabled = (@redoStack.length == 0)

  # Clears the undo/redo stacks.
  clearUndoStacks: ->
    @undoStack = []
    @redoStack = []
    $("#undo").get(0).disabled = true
    $("#redo").get(0).disabled = true

  # Removes the selection and puts it in the clipboard.
  cutSelection: ->
    return unless @selection.length > 0
    @setClipboard @cloneFeatures(@selection)
    @perform new AddRemoveFeaturesAction([], @selection)
    
  # Copies the selection to the clipboard.
  copySelection: ->
    return unless @selection.length > 0
    @setClipboard @cloneFeatures(@selection)

  setClipboard: (clipboard) ->
    @clipboard = clipboard
    $("#paste").get(0).disabled = (@clipboard.length == 0)
  
  # Pastes the selection into the playfield.
  pasteSelection: ->
    return unless @clipboard.length > 0
    features = @cloneFeatures @clipboard
    minX = Number.MAX_VALUE
    minY = Number.MAX_VALUE
    maxX = -Number.MAX_VALUE
    maxY = -Number.MAX_VALUE
    for feature in features
      continue unless feature.bounds?
      minX = Math.min(minX, feature.bounds.x)
      minY = Math.min(minY, feature.bounds.y)
      maxX = Math.max(maxX, feature.bounds.right())
      maxY = Math.max(maxY, feature.bounds.bottom())
    clientX = @playfield.base.canvas.width / 2
    clientY = @playfield.base.canvas.height / 2
    if @mouseIn
      clientX = @mouseClientX
      clientY = @mouseClientY
    position = @playfield.base.getWorldPosition(clientX, clientY)
    tx = position.x - (minX + maxX) / 2
    ty = position.y - (minY + maxY) / 2
    for feature in features
      feature.translate(tx, ty)
    @perform new AddRemoveFeaturesAction(features, [])
    @setSelection features
    
  # Clones the supplied array of features.
  cloneFeatures: (features) ->
    feature.clone() for feature in features
  
  # Removes the selection.
  deleteSelection: ->
    return unless @selection.length > 0
    @perform new AddRemoveFeaturesAction([], @selection)

# Initialize after loading.
$(document).on "ready, page:change", ->
  return if $("#editor").length == 0
  element = $("#editor").get(0)
  return if element.initialized
  element.initialized = true
  trackEditor = new TrackEditor
