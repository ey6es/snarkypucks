# Contains the playfield state/rendering business

root = exports ? this

# The base feature class.
class root.Feature
  # The size of our highlights
  @HIGHLIGHT_SIZE: 3
  
  # The function used to sort features for display and input.
  @SORT_FUNCTION: (a, b) ->
    if a.zOrder != b.zOrder then a.zOrder - b.zOrder else a.addOrder - b.addOrder
  
  # Creates a feature from its JSON representation.
  @fromJSON: (json) ->
    feature = new root[json.type]()
    feature.fromJSON(json)
    feature
      
  constructor: (@zOrder = 0) ->
    @visible = true
    @mousable = false
    @visibleInGame = true
    @collidable = true
    @reflectivity = 1
  
  # Sets the feature's visible state.
  setVisible: (visible) ->
    return if visible == @visible
    @visible = visible
    @dirty()
  
  # Sets the feature's z order (features are rendered in order of increasing z order).
  setZOrder: (zOrder) ->
    return if zOrder == @zOrder
    @zOrder = zOrder
    @dirty()
  
  # Sets whether or not the feature is visible in game mode.
  setVisibleInGame: (visible) ->
    @visibleInGame = visible
    @dirty()
  
  # Sets whether or not pucks can collide with this feature.
  setCollidable: (collidable) ->
    @collidable = collidable
  
  # Sets the amount of reflectivity applied on collision (0 stops the puck, 1 reflects all energy, 2 reflects 2x, etc.)
  setReflectivity: (reflectivity) ->
    @reflectivity = reflectivity
  
  # Sets the click handler for the feature.
  setClickHandler: (handler) ->
    @clickHandler = handler
    @mousable = @clickHandler?
  
  # Sets the bounding rectangle of the feature.  If the forceDirty parameter is set, dirties
  # the bounds even if they don't change.
  setBounds: (bounds, forceDirty = false) ->
    unless @layer?
      @bounds = bounds
      return
    if @bounds?
      if @bounds.equals(bounds)
        @dirty() if forceDirty
        return
    else
      return unless bounds?
    storedLayer = @layer
    storedLayer.removeFeature(this)
    @bounds = bounds
    storedLayer.addFeature(this)
  
  # Translates by the specified amount.
  translate: (x, y) ->
  
  # Rotates by the specified amount about the provided center.
  rotate: (x, y, angle) ->
  
  # Scales by the specified amount about the provided center.
  scale: (x, y, amount) ->
  
  # Sets (or clears) the feature's highlight color.
  setHighlightColor: (color) ->
  
  # Sets the feature's playfield reference, if it stores one.
  setPlayfield: (playfield) ->
  
  # Returns a cloned instance of this feature.
  clone: (feature = undefined) ->
    feature ?= new Feature()
    feature.setVisible @visible
    feature.setZOrder @zOrder
    feature.setVisibleInGame @visibleInGame
    feature.setCollidable @collidable
    feature.setReflectivity @reflectivity
    feature
  
  # Returns the JSON representation of this feature.
  toJSON: (json = undefined) ->
    json ?= { type: "Feature" }
    json.visible = @visible
    json.zOrder = @zOrder
    json.visibleInGame = @visibleInGame
    json.collidable = @collidable
    json.reflectivity = @reflectivity
    json
  
  # Initializes this feature from its JSON representation.
  fromJSON: (json) ->
    @setVisible json.visible if json.visible?
    @setZOrder json.zOrder if json.zOrder?
    @setVisibleInGame json.visibleInGame if json.visibleInGame?
    @setCollidable json.collidable if json.collidable?
    @setReflectivity json.reflectivity if json.reflectivity?
  
  # Dirties the area covered by this feature.
  dirty: ->
    @layer.dirty(@bounds) if @layer?
  
  # Draws the feature to the supplied context with the given clip regions.
  draw: (ctx, dirtyRegions) ->

  # Returns an array containing the snap points closest to the point specified.  The edges
  # flag determines whether edges, as well as vertices, should be included in the search.
  getSnapPoints: (point, edges = false) ->
    []
  
  # Sets the position of one of the snap point (vertices).
  setSnapPoint: (index, point) ->
  
  # Checks this feature for intersection with a circle.
  intersectsCircle: (center, radius) ->
    false
  
  # Checks this feature for intersection with a polygon.
  intersectsPolygon: (vertices) ->
    false
  
  # Checks this feature for a collision with the described path segment.  If found, returns an array containing
  # the proportional collision distance (0 for start, 1 for end) and the new end location.
  getPathSegmentCollision: (puck, prediction, start, end) ->
    undefined
  
  # Returns the penetration vector that would separate the given puck from this feature, if any.
  getPenetrationVector: (puck) ->
    undefined
  
  # Handles a mouse down event.
  mousedown: ->
    @clickHandler(this) if @clickHandler?
  
  # Handles a mouse up event.
  mouseup: ->
  
  # Handles a mouse enter event.
  mouseenter: ->
    @setHighlightColor "#000000"
    
  # Handles a mouse leave event.
  mouseleave: ->
    @setHighlightColor undefined
  
  # Handles a mouse move event.
  mousemove: ->
      

# An image feature.
class root.ImageFeature extends Feature
  # Retrieves an image through the cache.
  @getImage: (url) ->
    cached = @imageCache[url]
    return cached if cached?
    @imageCache[url] = cached = document.createElement "img"
    cached.src = url
    cached

  constructor: (@translation = new Point(), @rotation = 0, @url = "") ->
    super
    @alpha = 1
    @role = "none"
    @updateImage()
  
  # Sets the position at which to draw the image.
  setPosition: (translation, rotation = 0) ->
    @translation = translation
    @rotation = rotation
    @updateBounds true
  
  # Sets the URL of the image to display.
  setURL: (url) ->
    @url = url
    @updateImage()
  
  # Sets the alpha value of the image.
  setAlpha: (alpha) ->
    @alpha = alpha
    @dirty()
  
  # Sets the image's role.
  setRole: (role) ->
    @role = role
    
  # Updates the image (etc.) based on the URL.
  updateImage: ->
    if @listener?
      @image.removeEventListener "load", @listener
      @listener = undefined 
    @image = ImageFeature.getImage(@url)
    unless @image.complete
      @listener = (event) =>
        @updateBounds true
        @image.removeEventListener "load", @listener
        @listener = undefined
      @image.addEventListener "load", @listener
    @updateBounds true
  
  translate: (x, y) ->
    @setPosition @translation.translated(x, y), @rotation
    
  rotate: (x, y, angle) ->
    @setPosition @translation.rotated(x, y, angle), @rotation + angle
  
  scale: (x, y, amount) ->
    @setPosition @translation.scaled(x, y, amount), @rotation
  
  setHighlightColor: (color) ->
    @highlightColor = color
    @updateBounds true
    
  clone: (feature = undefined) ->
    feature ?= new ImageFeature()
    feature.setPosition @translation, @rotation
    feature.setURL @url
    feature.setAlpha @alpha
    feature.setRole @role
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "ImageFeature" }
    json.translation = @translation.toJSON()
    json.rotation = @rotation
    json.url = @url
    json.alpha = @alpha
    json.role = @role
    json.width = @image.naturalWidth
    json.height = @image.naturalHeight
    super json
  
  fromJSON: (json) ->
    @setPosition Point.fromJSON(json.translation), json.rotation
    @setURL json.url if json.url?
    @setAlpha json.alpha if json.alpha?
    @setRole json.role if json.role?
    @prompt = json.prompt
    super json
  
  draw: (ctx, dirtyRegions) ->
    if @highlightColor?
      ctx.strokeStyle = @highlightColor
      ctx.lineWidth = Feature.HIGHLIGHT_SIZE * 2
      ctx.lineCap = "round"
      ctx.globalAlpha = 1
      ctx.beginPath()
      ctx.moveTo @vertices[0].x, @vertices[0].y
      for index in [1...@vertices.length]
        ctx.lineTo @vertices[index].x, @vertices[index].y
      ctx.lineTo @vertices[0].x, @vertices[0].y
      ctx.stroke()
    return unless @image.complete
    ctx.globalAlpha = @alpha
    ctx.translate @translation.x - 0.5, @translation.y - 0.5
    ctx.rotate @rotation
    ctx.drawImage @image, Math.round(-@image.naturalWidth / 2), Math.round(-@image.naturalHeight / 2)
    ctx.rotate -@rotation
    ctx.translate -@translation.x + 0.5, -@translation.y + 0.5
    
  # Updates the feature's bounds.
  updateBounds: (forceDirty = false) ->
    left = @translation.x - @image.naturalWidth / 2
    top = @translation.y - @image.naturalHeight / 2
    right = @translation.x + @image.naturalWidth / 2
    bottom = @translation.y + @image.naturalHeight / 2
    @vertices = [
      new Point(left, top).rotated(@translation.x, @translation.y, @rotation)
      new Point(right, top).rotated(@translation.x, @translation.y, @rotation)
      new Point(right, bottom).rotated(@translation.x, @translation.y, @rotation)
      new Point(left, bottom).rotated(@translation.x, @translation.y, @rotation)
    ]
    @setBounds Polygon.getBounds(@vertices, 1 + (if @highlightColor? then Feature.HIGHLIGHT_SIZE else 0)).roundUp(), forceDirty
  
  getSnapPoints: (point, edges = false) ->
    [ @translation ]
  
  setSnapPoint: (index, point) ->
    @setPosition point, @rotation
  
  intersectsCircle: (center, radius) ->
    Polygon.getClosestPoint(@vertices, center).distance(center) < radius
  
  intersectsPolygon: (vertices) ->
    Polygon.intersectsPolygon @vertices, vertices
  
  getPathSegmentCollision: (puck, prediction, start, end) ->
    # prompts disappear when hit
    if @prompt? && !prediction && Polygon.getPathSegmentCollision(@vertices, puck.getExpandedRadius(), start, end, 1)?
      @setVisible false
      @prompt = undefined
      return undefined
    return undefined unless @collidable
    if @role != "boost" && @role != "omniboost"
      return Polygon.getPathSegmentCollision(@vertices, puck.getExpandedRadius(), start, end, @reflectivity)
    return undefined if puck.lastCollisionFeature == this
    closest = LineSegment.getClosestPoint(start, end, @translation)
    if closest.distance(@translation) >= puck.getExpandedRadius()
      return undefined
    t = LineSegment.getProjection(start, end, closest)
    vector = end.subtracted(closest)
    length = vector.length()
    return undefined if length == 0
    if @role == "boost"
      vector = new Point(0.0, -length).rotated(0.0, 0.0, @rotation)
    vector.scale(@reflectivity)
    [ t, closest.plus(vector) ]
    
  getPenetrationVector: (puck) ->
    return undefined unless @collidable && @role != "boost" && @role != "omniboost"
    Polygon.getPenetrationVector(@vertices, puck.center, puck.getExpandedRadius())
    
  @imageCache: {}
  
  
# Base class for wrapped styles.
class root.Style
  # Creates a wrapped style from its JSON representation.
  @fromJSON: (json) ->
    return new Style(json) unless json? && json.type?
    new Pattern(json.url, json.repeatType)
  
  constructor: (@style = null) ->
    @complete = true
    @offset = false
    if @style? then @type = "color" else @type = "none"
  
  # Returns the JSON representation of the style.
  toJSON: ->
    @style
  
  
# A pattern style.
class root.Pattern extends Style
  constructor: (@url, @repeatType = "repeat") ->
    @type = "pattern"
    @image = ImageFeature.getImage(@url)
    @complete = @image.complete
    @offset = true
    if @complete
      @style = StrokedFeature.ctx.createPattern @image, @repeatType
    else
      @listener = (event) =>
        @complete = true
        @style = StrokedFeature.ctx.createPattern @image, @repeatType
        @image.removeEventListener "load", @listener
        @listener = undefined
      @image.addEventListener "load", @listener
      
  # Adds a listener to notify on completion.
  addCompletionListener: (listener) ->
    @image.addEventListener "load", listener
  
  # Removes a completion listener.
  removeCompletionListener: (listener) ->
    @image.removeEventListener "load", listener
   
  toJSON: ->
    { type: "pattern", url: @url, repeatType: @repeatType }
  
  
# Base class for stroked features.
class root.StrokedFeature extends Feature
  constructor: (zOrder = 0) ->
    super zOrder
    @strokeStyle = new Style("#000000")
    @strokeAlpha = 1
    @lineWidth = 1
    @lineCap = "round"
    @lineJoin = "round"
    @updateBounds()

  # Sets the line style.
  setStrokeStyle: (style) ->
    if @strokeStyleListener?
      @strokeStyle.removeCompletionListener(@strokeStyleListener)
      @strokeStyleListener = undefined
    @strokeStyle = style
    unless @strokeStyle.complete
      @strokeStyleListener = (event) =>
        @dirty()
        @strokeStyle.removeCompletionListener(@strokeStyleListener)
        @strokeStyleListener = undefined
      @strokeStyle.addCompletionListener(@strokeStyleListener)
    @dirty()

  # Sets the stroke alpha.
  setStrokeAlpha: (alpha) ->
    @strokeAlpha = alpha
    @dirty()
  
  # Sets the line width.
  setLineWidth: (width) ->
    return if width == @lineWidth
    @lineWidth = width
    @updateBounds true
  
  # Sets the line cap.
  setLineCap: (cap) ->
    return if cap == @lineCap
    @lineCap = cap
    @dirty()
  
  # Sets the line join.
  setLineJoin: (join) ->
    return if join == @lineJoin
    @lineJoin = join
    @dirty()
  
  # Returns the radius of the stroke.
  getStrokeRadius: ->
    if @strokeStyle.style? then @lineWidth / 2 else 0
  
  setHighlightColor: (color) ->
    @highlightColor = color
    @updateBounds true
  
  # Updates the feature's bounds.
  updateBounds: (forceDirty = false) ->
  
  clone: (feature = undefined) ->
    feature ?= new StrokedFeature()
    feature.setStrokeStyle @strokeStyle
    feature.setStrokeAlpha @strokeAlpha
    feature.setLineWidth @lineWidth
    feature.setLineCap @lineCap
    feature.setLineJoin @lineJoin
    feature.setHighlightColor @highlightColor
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "StrokedFeature" }
    json.strokeStyle = @strokeStyle.toJSON()
    json.strokeAlpha = @strokeAlpha
    json.lineWidth = @lineWidth
    json.lineCap = @lineCap
    json.lineJoin = @lineJoin
    super json
  
  fromJSON: (json) ->
    @setStrokeStyle Style.fromJSON(json.strokeStyle) if json.strokeStyle != undefined
    @setStrokeAlpha json.strokeAlpha if json.strokeAlpha?
    @setLineWidth json.lineWidth if json.lineWidth?
    @setLineCap json.lineCap if json.lineCap?
    @setLineJoin json.lineJoin if json.lineJoin?
    super json
    
  draw: (ctx, dirtyRegions) ->
    ctx.beginPath()
    @drawPath ctx, dirtyRegions
    @drawHighlight(ctx) if @highlightColor?
    @drawStroke(ctx) if @strokeStyle.style?
    
  # Draws the path to be stroked.
  drawPath: (ctx, dirtyRegions) ->

  # Draws the highlight portion of the feature.
  drawHighlight: (ctx) ->
    ctx.strokeStyle = @highlightColor
    ctx.lineWidth = @lineWidth + Feature.HIGHLIGHT_SIZE * 2
    ctx.lineCap = "round"
    ctx.globalAlpha = 1
    ctx.stroke()

  # Draws the stroked portion of the feature. 
  drawStroke: (ctx) ->
    ctx.strokeStyle = @strokeStyle.style
    ctx.lineWidth = @lineWidth
    ctx.lineCap = @lineCap
    ctx.lineJoin = @lineJoin
    ctx.globalAlpha = @strokeAlpha
    if @strokeStyle.offset
      ctx.translate -0.5, -0.5
      ctx.stroke()
      ctx.translate 0.5, 0.5
    else
      ctx.stroke()
      
  # A canvas used for pattern creation, text measurement.
  @canvas: document.createElement("canvas")
  
  # A context used for pattern creation, text measurement.
  @ctx: @canvas.getContext("2d")


# An infinite grid.
class root.Grid extends StrokedFeature
  constructor: ->
    super -Number.MAX_VALUE
    @spacing = 40
    @setStrokeStyle new Style("#D0D0D0")
    
  # Sets the grid spacing.
  setSpacing: (spacing) ->
    @spacing = spacing
    @dirty()

  clone: (feature = undefined) ->
    feature ?= new Grid()
    feature.setSpacing @spacing
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "Grid" }
    json.spacing = @spacing
    super json
  
  fromJSON: (json) ->
    @setSpacing json.spacing if json.spacing?
    super json
    
  drawPath: (ctx, dirtyRegions) ->
    for dirtyRegion in dirtyRegions
      for x in [Math.ceil(dirtyRegion.left() / @spacing)..Math.floor(dirtyRegion.right() / @spacing)]
        ctx.moveTo x * @spacing, dirtyRegion.top()
        ctx.lineTo x * @spacing, dirtyRegion.bottom()
      for y in [Math.ceil(dirtyRegion.top() / @spacing)..Math.floor(dirtyRegion.bottom() / @spacing)]
        ctx.moveTo dirtyRegion.left(), y * @spacing
        ctx.lineTo dirtyRegion.right(), y * @spacing


# A line segment.
class root.LineSegment extends StrokedFeature
  # The index of the path segment in the associated features list.
  @PATH_INDEX: 0
  
  # The index of the left wall in the associated features list.
  @LEFT_INDEX: 1
  
  # The index of the right wall in the associated features list.
  @RIGHT_INDEX: 2
  
  # The index of the bottom wall in the associated features list.
  @BOTTOM_INDEX: 3
  
  # The index of the top wall in the associated features list.
  @TOP_INDEX: 4
  
  # The index of the starting line in the associated features list.
  @START_INDEX: 5
  
  # The index of the finish line in the associated features list.
  @FINISH_INDEX: 6
  
  # The index of the path background in the associated features list.
  @PATH_BACKGROUND_INDEX: 7
  
  # The index of the bottom background in the associated features list.
  @BOTTOM_BACKGROUND_INDEX: 8
  
  # The index of the finish area in the associated features list.
  @FINISH_AREA_INDEX: 9
  
  # Returns the closest point on the described segment to the point given.
  @getClosestPoint: (start, end, point) ->
    return start if start.equals(end)
    length = start.distance(end)
    unitX = (end.x - start.x) / length
    unitY = (end.y - start.y) / length
    product = (point.x - start.x) * unitX + (point.y - start.y) * unitY
    if product < 0
      start
    else if product > length
      end
    else
      new Point(start.x + product * unitX, start.y + product * unitY)
  
  # Returns the projection of the specified point onto the described segment.
  @getProjection: (start, end, point) ->
    dx = end.x - start.x
    dy = end.y - start.y
    l2 = dx*dx + dy*dy
    return 0 if l2 == 0
    ((point.x - start.x) * dx + (point.y - start.y) * dy) / l2
  
  # Finds the intersection between the described segment and a circle.
  @getCircleIntersection: (start, end, center, radius) ->
    ox = start.x - center.x
    oy = start.y - center.y
    dx = end.x - start.x
    dy = end.y - start.y
    a = dx*dx + dy*dy 
    return undefined if a == 0
    b = 2 * (dx*ox + dy*oy)
    c = ox*ox + oy*oy - radius*radius
    radicand = b*b - 4*a*c
    return undefined if radicand < 0
    radical = Math.sqrt(radicand)
    t = (-b - radical) / (2*a)
    t = (-b + radical) / (2*a) if t < 0
    return undefined if (t < 0 || t > 1)
    new Point(start.x + t * dx, start.y + t * dy)
  
  # Checks for a collision between the described segment and path segment.
  @getPathSegmentCollision: (start, end, radius, pathStart, pathEnd, reflectivity) ->
    length = start.distance(end)
    if length == 0
      return Circle.getPathSegmentCollision(start, radius, pathStart, pathEnd, reflectivity)
    tx = (end.x - start.x) / length
    ty = (end.y - start.y) / length # line tangent
    nx = -ty
    ny = tx # line normal
    ox = pathStart.x - start.x
    oy = pathStart.y - start.y
    dividend = ox*nx + oy*ny
    if -radius < dividend < radius
      projection = ox*tx + oy*ty
      if projection < 0
        return Circle.getPathSegmentCollision(start, radius, pathStart, pathEnd, reflectivity)
      if projection > length
        return Circle.getPathSegmentCollision(end, radius, pathStart, pathEnd, reflectivity)
    dx = pathEnd.x - pathStart.x
    dy = pathEnd.y - pathStart.y
    divisor = dx*nx + dy*ny
    if dividend < 0
      return undefined if divisor <= 0  
      dividend = -radius - dividend
    else
      return undefined if divisor >= 0
      dividend = radius - dividend
    t = dividend / divisor
    return undefined if (t < 0 || t > 1)
    cx = ox + t*dx
    cy = oy + t*dy
    projection = cx*tx + cy*ty
    if projection < 0
      return Circle.getPathSegmentCollision(start, radius, pathStart, pathEnd, reflectivity)
    if projection > length
      return Circle.getPathSegmentCollision(end, radius, pathStart, pathEnd, reflectivity)
    remaining = 1 - t
    px = dx * remaining
    py = dy * remaining # penetration vector
    dotProduct = tx*px + ty*py
    rx = 2*dotProduct*tx - px
    ry = 2*dotProduct*ty - py # reflection vector
    [ t, new Point(pathStart.x + t*dx + rx*reflectivity, pathStart.y + t*dy + ry*reflectivity) ] 
  
  # Find the penetration vector for the specified segment and circle.
  @getPenetrationVector: (start, end, center, radius) ->
    Circle.getPenetrationVector(LineSegment.getClosestPoint(start, end, center), center, radius)
    
  # Finds the intersection between two lines.
  @getLineLineIntersection: (firstStart, firstEnd, secondStart, secondEnd) ->
    nx = firstStart.y - firstEnd.y
    ny = firstEnd.x - firstStart.x
    dx = secondEnd.x - secondStart.x
    dy = secondEnd.y - secondStart.y
    divisor = nx*dx + ny*dy
    return undefined if divisor == 0
    t = ((nx*firstStart.x + ny*firstStart.y) - (nx*secondStart.x + ny*secondStart.y)) / divisor
    new Point(secondStart.x + t*dx, secondStart.y + t*dy)
    
  constructor: (@start = new Point(), @end = new Point()) ->
    super 0
    @role = "none"

  # Returns the length of the line.
  getLength: ->
    @start.distance(@end)
  
  # Sets the line endpoints.
  setEndpoints: (start, end) ->
    @start = start
    @end = end
    @updateBounds true
  
  # Sets the line's role.
  setRole: (role) ->
    @role = role
    @setCollidable(false) unless @role == "none" || @role == "finish-line"
  
  # Finds the intersection between the segment and a line.
  getLineIntersection: (start, end) ->
    nx = @start.y - @end.y
    ny = @end.x - @start.x
    dx = end.x - start.x
    dy = end.y - start.y
    divisor = nx*dx + ny*dy
    return undefined if divisor == 0
    t = ((nx*@start.x + ny*@start.y) - (nx*start.x + ny*start.y)) / divisor
    ix = start.x + t*dx
    iy = start.y + t*dy
    dx = @end.x - @start.x
    dy = @end.y - @start.y
    ot = (if Math.abs(dx) > Math.abs(dy) then (ix - @start.x) / dx else (iy - @start.y) / dy)
    return (if ot >= 0 && ot <= 1 then t else undefined)
  
  # Checks whether the specified point is on a feature with the given role.
  isOnFeature: (point, radius, role) ->
    return false unless @features?
    for feature in @features
      return true if feature? && feature.intersectsCircle(point, radius) && feature.role == role
    false
    
  clone: (feature = undefined, reversed = false) ->
    feature ?= new LineSegment()
    if reversed
      feature.setEndpoints @end, @start
    else
      feature.setEndpoints @start, @end
    feature.setRole @role
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "LineSegment" }
    json.start = @start.toJSON()
    json.end = @end.toJSON()
    json.role = @role
    super json
  
  fromJSON: (json) ->
    @setEndpoints Point.fromJSON(json.start), Point.fromJSON(json.end)
    @setRole json.role if json.role?
    super json
    
  translate: (x, y) ->
    @setEndpoints @start.translated(x, y), @end.translated(x, y)
  
  rotate: (x, y, angle) ->
    @setEndpoints @start.rotated(x, y, angle), @end.rotated(x, y, angle)
  
  scale: (x, y, amount) ->
    @setEndpoints @start.scaled(x, y, amount), @end.scaled(x, y, amount)
  
  updateBounds: (forceDirty = false) ->
    # expand to cover width, highlight (if any)
    expansion = Math.ceil(@lineWidth / 2) + 1 + (if @highlightColor? then Feature.HIGHLIGHT_SIZE else 0)
    minX = Math.min(@start.x, @end.x) - expansion
    minY = Math.min(@start.y, @end.y) - expansion
    @setBounds(new Rectangle(minX, minY, Math.max(@start.x, @end.x) - minX + expansion,
      Math.max(@start.y, @end.y) - minY + expansion).roundUp(), forceDirty)
  
  drawPath: (ctx, dirtyRegions) ->
    ctx.moveTo @start.x, @start.y
    ctx.lineTo @end.x, @end.y
  
  getSnapPoints: (point, edges = false) ->
    if edges
      [ LineSegment.getClosestPoint(@start, @end, point) ]
    else
      [ @start, @end ]
  
  setSnapPoint: (index, point) ->
    if index == 0 then @setEndpoints(point, @end) else @setEndpoints(@start, point)
    
  intersectsCircle: (center, radius) ->
    LineSegment.getClosestPoint(@start, @end, center).distance(center) < radius + @lineWidth / 2

  intersectsPolygon: (vertices) ->
    return false if @allPointsOutsideEdge(@start, @end, vertices)
    return false if @allPointsOutsideEdge(@end, @start, vertices)
    # TODO: are these next two actually necessary?
    return false if @allPointsOutsideEdge(@start,
      new Point(@start.x + (@end.y - @start.y), @start.y + (@start.x - @end.x)), vertices)
    return false if @allPointsOutsideEdge(@end,
      new Point(@end.x + (@start.y - @end.y), @end.y + (@end.x - @start.x)), vertices)
    orientation = Polygon.getOrientation(vertices)
    for index in [0...vertices.length]
      return false if @bothEndpointsOutsideEdge(vertices, orientation, index)
    true
  
  getPathSegmentCollision: (puck, prediction, start, end) ->
    return undefined unless @collidable && !(prediction && @role == "finish-line")
    LineSegment.getPathSegmentCollision(@start, @end, @lineWidth / 2 + puck.getExpandedRadius(), start, end, @reflectivity)
  
  getPenetrationVector: (puck) ->
    return undefined unless @collidable
    LineSegment.getPenetrationVector(@start, @end, puck.center, @lineWidth / 2 + puck.getExpandedRadius())
    
  # Checks whether all points are outside the described edge.
  allPointsOutsideEdge: (start, end, points) ->
    edgeX = end.x - start.x
    edgeY = end.y - start.y
    length = Math.sqrt(edgeX * edgeX + edgeY * edgeY)
    return false if length == 0
    scale = 1 / length
    edgeX *= scale
    edgeY *= scale
    expansion = @lineWidth / 2
    for point in points
      return false if (point.x - start.x) * edgeY - edgeX * (point.y - start.y) < expansion
    return true
  
  # Checks whether both endpoints are outside the described edge.
  bothEndpointsOutsideEdge: (vertices, orientation, index) ->
    start = vertices[index]
    end = vertices[(index + 1) % vertices.length]
    edgeX = end.x - start.x
    edgeY = end.y - start.y
    length = Math.sqrt(edgeX * edgeX + edgeY * edgeY)
    return false if length == 0
    scale = orientation / length
    edgeX *= scale
    edgeY *= scale
    expansion = @lineWidth / 2
    (@start.x - start.x) * edgeY - edgeX * (@start.y - start.y) >= expansion &&
      (@end.x - start.x) * edgeY - edgeX * (@end.y - start.y) >= expansion
    

# A line segment with an arrowhead at the end.
class Arrow extends LineSegment
  # The size of the head.
  @HEAD_SIZE: 10
  
  constructor: (start = new Point(), end = new Point()) ->
    super start, end
  
  updateBounds: (forceDirty = false) ->
    # expand to cover width, highlight (if any)
    expansion = Arrow.HEAD_SIZE + Math.ceil(@lineWidth / 2) + 1 + (if @highlightColor? then Feature.HIGHLIGHT_SIZE else 0)
    minX = Math.min(@start.x, @end.x) - expansion
    minY = Math.min(@start.y, @end.y) - expansion
    @setBounds(new Rectangle(minX, minY, Math.max(@start.x, @end.x) - minX + expansion,
      Math.max(@start.y, @end.y) - minY + expansion).roundUp(), forceDirty)
      
  drawPath: (ctx, dirtyRegions) ->
    super ctx, dirtyRegions
    length = @start.distance(@end)
    return if length == 0
    scale = Arrow.HEAD_SIZE / length
    base = new Point(@end.x + (@start.x - @end.x) * scale, @end.y + (@start.y - @end.y) * scale)
    left = base.rotated(@end.x, @end.y, Math.PI / 6)
    right = base.rotated(@end.x, @end.y, -Math.PI / 6)
    ctx.lineTo left.x, left.y
    ctx.moveTo @end.x, @end.y
    ctx.lineTo right.x, right.y
    

# A circular arc.
class root.Arc extends StrokedFeature
  # Returns the length of the arc between the first and second angles.
  @getLength: (firstAngle, secondAngle) ->
    (if secondAngle > firstAngle then 0 else Math.PI * 2) + secondAngle - firstAngle
  
  # Ensures that the given angle is in [-pi,pi].
  @normalizeAngle: (angle) ->
    angle += 2 * Math.PI while angle < -Math.PI
    angle -= 2 * Math.PI while angle > Math.PI
    angle
      
  constructor: (@center = new Point(), @radius = 0, @startAngle = -Math.PI, @endAngle = Math.PI) ->
    super 0
    @updatePoints()

  # Sets all of the arc parameters.
  setParameters: (center, radius, startAngle = -Math.PI, endAngle = Math.PI) ->
    @center = center
    @radius = radius
    @startAngle = startAngle
    @endAngle = endAngle
    @updatePoints()
    @updateBounds true

  clone: (feature = undefined) ->
    feature ?= new Arc()
    feature.setParameters @center, @radius, @startAngle, @endAngle
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "Arc" }
    json.center = @center.toJSON()
    json.radius = @radius
    json.startAngle = @startAngle
    json.endAngle = @endAngle
    super json
  
  fromJSON: (json) ->
    @setParameters Point.fromJSON(json.center), json.radius, json.startAngle, json.endAngle
    super json
    
  translate: (x, y) ->
    @setParameters @center.translated(x, y), @radius, @startAngle, @endAngle
  
  rotate: (x, y, angle) ->
    @setParameters @center.rotated(x, y, angle), @radius, Arc.normalizeAngle(@startAngle + angle),
      Arc.normalizeAngle(@endAngle + angle)
  
  scale: (x, y, amount) ->
    @setParameters @center.scaled(x, y, amount), @radius * amount, @startAngle, @endAngle
  
  updateBounds: (forceDirty = false) ->
    # expand to cover width
    expandedRadius = @radius + Math.ceil(@lineWidth / 2) + 1 + (if @highlightColor? then Feature.HIGHLIGHT_SIZE else 0)
    @setBounds(new Rectangle(@center.x - expandedRadius, @center.y - expandedRadius,
      expandedRadius * 2, expandedRadius * 2).roundUp(), forceDirty)
  
  drawPath: (ctx, dirtyRegions) ->
    ctx.arc @center.x, @center.y, @radius, @startAngle, @endAngle
    
  getSnapPoints: (point, edges = false) ->
    distance = @center.distance(point)
    if distance == 0
      return [ @center ]
    zero = new Point(@center.x + @radius, @center.y)
    angle = @getAngle(point)
    if edges  
      [ @center, zero.rotated(@center.x, @center.y, angle) ]
    else
      points = [ @center, zero.rotated(@center.x, @center.y, @startAngle), zero.rotated(@center.x, @center.y, @endAngle) ]
      if angle != @startAngle && angle != @endAngle
        points.push zero.rotated(@center.x, @center.y, angle)
      points
      
  setSnapPoint: (index, point) ->
    if index == 0
      @setParameters point, @radius, @startAngle, @endAngle
      return
    radius = @center.distance(point)
    if index == 3
      @setParameters @center, radius, @startAngle, @endAngle
      return
    if radius == 0
      return
    angle = Math.atan2(point.y - @center.y, point.x - @center.x)
    if index == 1
      @setParameters @center, @radius, angle, @endAngle
    else
      @setParameters @center, @radius, @startAngle, angle
    
  intersectsCircle: (center, radius) ->
    distance = @center.distance(center)
    expansion = radius + @lineWidth / 2
    return distance < @radius + expansion if @radius == 0
    return false if distance > @radius + expansion
    return false if distance < @radius - expansion
    angle = Math.atan2(center.y - @center.y, center.x - @center.x)
    Arc.containsAngle(@startAngle, @endAngle, angle) || @startPoint.distance(center) <= expansion ||
      @endPoint.distance(center) <= expansion
      
  intersectsPolygon: (vertices) ->
    return Polygon.getClosestPoint(vertices, @center).distance(@center) < @radius + @lineWidth / 2 if @radius == 0
    orientation = Polygon.getOrientation(vertices)
    expansion = @lineWidth / 2
    expandedRadius = @radius + expansion
    shrunkRadius = @radius - expansion
    allInside = true
    for index in [0...vertices.length]
      start = vertices[index]
      end = vertices[(index + 1) % vertices.length]
      t0 = Arc.getSegmentIntersection(start, end, @center, expandedRadius, @startAngle, @endAngle)
      t1 = Arc.getSegmentIntersection(start, end, @center, shrunkRadius, @startAngle, @endAngle)
      t2 = Arc.getSegmentIntersection(start, end, @startPoint, expansion)
      t3 = Arc.getSegmentIntersection(start, end, @endPoint, expansion)
      unless t0? || t1? || t2? || t3?
        return false if Polygon.isOutsideEdge(vertices, orientation, @startPoint, index)
        continue
      allInside = false
      if (t0 >= 0 && t0 <= 1) || (t1 >= 0 && t1 <= 1) || (t2 >= 0 && t2 <= 1) || (t3 >= 0 && t3 <= 1)
        return true
    allInside
  
  getPathSegmentCollision: (puck, prediction, start, end) ->
    return undefined unless @collidable
    expansion = @lineWidth / 2 + puck.getExpandedRadius()
    if @radius == 0
      return Circle.getPathSegmentCollision(@center, @radius + @lineWidth / 2 + puck.getExpandedRadius(),
        start, end, @reflectivity)
    t0 = Arc.getSegmentIntersection(start, end, @center, @radius + expansion, @startAngle, @endAngle, 1)
    t1 = Arc.getSegmentIntersection(start, end, @center, @radius - expansion, @startAngle, @endAngle, -1)
    t2 = Arc.getSegmentIntersection(start, end, @startPoint, expansion, -Math.PI, Math.PI, 1)
    t3 = Arc.getSegmentIntersection(start, end, @endPoint, expansion, -Math.PI, Math.PI, 1)
    t0 = undefined if t0 < 0 || t0 > 1
    t1 = undefined if t1 < 0 || t1 > 1
    t2 = undefined if t2 < 0 || t2 > 1
    t3 = undefined if t3 < 0 || t3 > 1
    if t0? && !(t0 > t1 || t0 > t2 || t0 > t3)
      t = t0
      center = @center
    else if t1? && !(t1 > t2 || t1 > t3)
      t = t1
      center = @center
    else if t2? && !(t2 > t3)
      t = t2
      center = @startPoint
    else if t3?
      t = t3
      center = @endPoint
    else
      return undefined
    dx = end.x - start.x
    dy = end.y - start.y
    tx = start.x - center.x + t*dx
    ty = start.y - center.y + t*dy # compute the collision tangent
    length = Math.sqrt(tx*tx + ty*ty)
    if length > 0
      tmp = tx
      tx = -ty / length 
      ty = tmp / length
    else
      tx = 1
      ty = 0
    remaining = 1 - t
    px = dx * remaining
    py = dy * remaining # penetration vector
    dotProduct = tx*px + ty*py
    rx = 2*dotProduct*tx - px
    ry = 2*dotProduct*ty - py # reflection vector
    [ t, new Point(start.x + t*dx + rx*@reflectivity, start.y + t*dy + ry*@reflectivity) ]
  
  getPenetrationVector: (puck) ->
    return undefined unless @collidable
    zero = new Point(@center.x + @radius, @center.y)
    closest = zero.rotated(@center.x, @center.y, @getAngle(puck.center))
    Circle.getPenetrationVector(closest, puck.center, @lineWidth / 2 + puck.getExpandedRadius())
  
  # Returns the angle corresponding to the given point.
  getAngle: (point) ->
    angle = Math.atan2(point.y - @center.y, point.x - @center.x)
    if @endAngle >= @startAngle
      angle = Math.min(Math.max(angle, @startAngle), @endAngle)
    else
      midpoint = @endAngle + (@startAngle - @endAngle) / 2
      if angle >= midpoint
        angle = Math.max(angle, @startAngle)
      else
        angle = Math.min(angle, @endAngle)
    angle
    
  # Updates our cached start/end points.
  updatePoints: ->
    @startPoint = new Point(@center.x + @radius * Math.cos(@startAngle), @center.y + @radius * Math.sin(@startAngle))
    @endPoint = new Point(@center.x + @radius * Math.cos(@endAngle), @center.y + @radius * Math.sin(@endAngle))
    
  # Finds the intersection between the described arc and a segment.
  @getSegmentIntersection: (start, end, center, radius, startAngle = -Math.PI, endAngle = Math.PI, orientation = 0) ->
    ox = start.x - center.x
    oy = start.y - center.y
    dx = end.x - start.x
    dy = end.y - start.y
    a = dx*dx + dy*dy 
    return undefined if a == 0
    b = 2 * (dx*ox + dy*oy)
    c = ox*ox + oy*oy - radius*radius
    radicand = b*b - 4*a*c
    return undefined if radicand < 0
    radical = Math.sqrt(radicand)
    first = (-b - radical) / (2*a)
    second = (-b + radical) / (2*a)
    fx = ox + first * dx
    fy = oy + first * dy
    first = undefined unless (fx*dx + fy*dy)*orientation <= 0 && @containsAngle(startAngle, endAngle, Math.atan2(fy, fx))
    sx = ox + second * dx
    sy = oy + second * dy
    second = undefined unless (sx*dx + sy*dy)*orientation <= 0 && @containsAngle(startAngle, endAngle, Math.atan2(sy, sx))
    return second unless first?
    return first unless second?
    return second unless first >= 0 && first <= 1 
    return first unless second >= 0 && second <= 1
    Math.min(first, second)
  
  # Checks whether the described arc contains the given angle.
  @containsAngle: (startAngle, endAngle, angle) ->
    if endAngle > startAngle
      return angle >= startAngle && angle <= endAngle
    angle >= startAngle || angle <= endAngle
  
  
# Base class for filled features (which may also be stroked for outlines).
class root.FilledFeature extends StrokedFeature
  constructor: (zOrder = 0) ->
    super zOrder
    @strokeStyle = new Style()
    @fillStyle = new Style("#000000")
    @fillAlpha = 1

  # Sets the fill style.
  setFillStyle: (style) ->
    if @fillStyleListener?
      @fillStyle.removeCompletionListener(@fillStyleListener)
      @fillStyleListener = undefined
    @fillStyle = style
    unless @fillStyle.complete
      @fillStyleListener = (event) =>
        @dirty()
        @fillStyle.removeCompletionListener(@fillStyleListener)
        @fillStyleListener = undefined
      @fillStyle.addCompletionListener(@fillStyleListener)
    @dirty()
  
  # Sets the fill alpha
  setFillAlpha: (alpha) ->
    @fillAlpha = alpha
    @dirty()
  
  clone: (feature = undefined) ->
    feature ?= new FilledFeature()
    feature.setFillStyle @fillStyle
    feature.setFillAlpha @fillAlpha
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "FilledFeature" }
    json.fillStyle = @fillStyle.toJSON()
    json.fillAlpha = @fillAlpha
    super json
  
  fromJSON: (json) ->
    @setFillStyle Style.fromJSON(json.fillStyle) if json.fillStyle != undefined
    @setFillAlpha json.fillAlpha if json.fillAlpha?
    super json
    
  draw: (ctx, dirtyRegions) ->
    ctx.beginPath()
    @drawPath ctx, dirtyRegions
    @drawHighlight(ctx) if @highlightColor?
    if @fillStyle.style?
      ctx.fillStyle = @fillStyle.style
      ctx.globalAlpha = @fillAlpha
      if @fillStyle.offset
        ctx.translate -0.5, -0.5
        ctx.fill()
        ctx.translate 0.5, 0.5
      else
        ctx.fill()  
    @drawStroke(ctx) if @strokeStyle.style?
  
  
# A circle.
class root.Circle extends FilledFeature
  # Checks for a collision between the described circle and path segment.
  @getPathSegmentCollision: (center, radius, start, end, reflectivity) ->
    ox = start.x - center.x
    oy = start.y - center.y
    dx = end.x - start.x
    dy = end.y - start.y
    a = dx*dx + dy*dy
    return undefined if a == 0
    b = 2 * (dx*ox + dy*oy)
    return undefined if b >= 0 # make sure we're heading towards the circle
    c = ox*ox + oy*oy - radius*radius
    radicand = b*b - 4*a*c
    return undefined if radicand < 0
    radical = Math.sqrt(radicand)
    t = (-b - radical) / (2*a)
    return undefined if (t < 0 || t > 1)
    tx = ox + t*dx
    ty = oy + t*dy # compute the collision tangent
    length = Math.sqrt(tx*tx + ty*ty)
    if length > 0
      tmp = tx
      tx = -ty / length 
      ty = tmp / length
    else
      tx = 1
      ty = 0
    remaining = 1 - t
    px = dx * remaining
    py = dy * remaining # penetration vector
    dotProduct = tx*px + ty*py
    rx = 2*dotProduct*tx - px
    ry = 2*dotProduct*ty - py # reflection vector
    [ t, new Point(start.x + t*dx + rx*reflectivity, start.y + t*dy + ry*reflectivity) ] 

  # Returns the penetration vector for the described circles.
  @getPenetrationVector: (point, center, combinedRadius) ->
    dx = center.x - point.x
    dy = center.y - point.y
    length = Math.sqrt(dx*dx + dy*dy)
    if length == 0
      dx = 1
      dy = 0
    else
      dx /= length
      dy /= length
    scale = combinedRadius - length
    new Point(dx * scale, dy * scale)
  
  constructor: (@center = new Point(), @radius = 0) ->
    super 0
  
  # Sets both of the circle's parameters.
  setParameters: (center, radius) ->
    @center = center
    @radius = radius
    @updateBounds true
  
  clone: (feature = undefined) ->
    feature ?= new Circle()
    feature.setParameters @center, @radius
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "Circle" }
    json.center = @center.toJSON()
    json.radius = @radius
    super json
  
  fromJSON: (json) ->
    @setParameters Point.fromJSON(json.center), json.radius
    super json
    
  translate: (x, y) ->
    @setParameters @center.translated(x, y), @radius
  
  rotate: (x, y, angle) ->
    @setParameters @center.rotated(x, y, angle), @radius
    
  scale: (x, y, amount) ->
    @setParameters @center.scaled(x, y, amount), @radius * amount
  
  updateBounds: (forceDirty = false) ->
    # expand to cover width
    expandedRadius = @radius + Math.ceil(@lineWidth / 2) + 1 + (if @highlightColor? then Feature.HIGHLIGHT_SIZE else 0)
    @setBounds(new Rectangle(@center.x - expandedRadius, @center.y - expandedRadius,
      expandedRadius * 2, expandedRadius * 2).roundUp(), forceDirty)
  
  drawPath: (ctx, dirtyRegions) ->
    ctx.arc @center.x, @center.y, @radius, 0, 2 * Math.PI
  
  getSnapPoints: (point, edges = false) ->
    [ @center, @getClosestEdgePoint(point) ]
  
  setSnapPoint: (index, point) ->
    if index == 0 then @setParameters(point, @radius) else @setParameters(@center, point.distance(@center))
    
  # Returns the point on the circle's edge closest to the one specified.
  getClosestEdgePoint: (point) ->
    return @center if point.equals(@center)
    dx = point.x - @center.x
    dy = point.y - @center.y
    multiplier = @radius / Math.sqrt(dx*dx + dy*dy);
    new Point(@center.x + dx * multiplier, @center.y + dy * multiplier)
  
  intersectsCircle: (center, radius) ->
    @center.distance(center) < radius + @getExpandedRadius()

  intersectsPolygon: (vertices) ->
    Polygon.getClosestPoint(vertices, @center).distance(@center) < @getExpandedRadius()
  
  getPathSegmentCollision: (puck, prediction, start, end) ->
    return undefined unless @collidable
    Circle.getPathSegmentCollision(@center, @getExpandedRadius() + puck.getExpandedRadius(), start, end, @reflectivity)
  
  getPenetrationVector: (puck) ->
    return undefined unless @collidable
    Circle.getPenetrationVector(@center, puck.center, @getExpandedRadius() + puck.getExpandedRadius())
    
  # Returns the radius plus the line width, if any.
  getExpandedRadius: ->
    @radius + @getStrokeRadius()


# A convex polygon.
class root.Polygon extends FilledFeature
  # Computes the bounds of the described polygon.
  @getBounds: (vertices, expansion = 0) ->
    minX = minY = Number.MAX_VALUE
    maxX = maxY = -Number.MAX_VALUE
    for vertex in vertices
      minX = Math.min(minX, vertex.x)
      minY = Math.min(minY, vertex.y)
      maxX = Math.max(maxX, vertex.x)
      maxY = Math.max(maxY, vertex.y)
    new Rectangle(minX - expansion, minY - expansion, maxX - minX + expansion * 2, maxY - minY + expansion * 2)

  # Returns the closest point on (or in) the polygon to the one specified.
  @getClosestPoint: (vertices, point) ->
    orientation = @getOrientation(vertices)
    outsideLastLast = @isOutsideEdge(vertices, orientation, point, vertices.length - 2)
    outsideLast = @isOutsideEdge(vertices, orientation, point, vertices.length - 1)
    for index in [0...vertices.length]
      outside = @isOutsideEdge(vertices, orientation, point, index)
      if outsideLast
        if outside then return vertices[index]
        else unless outsideLastLast
          return LineSegment.getClosestPoint(vertices[(index + vertices.length - 1) % vertices.length], vertices[index], point)
      outsideLastLast = outsideLast
      outsideLast = outside
    point
      
  # Checks whether one polygon intersects another.
  @intersectsPolygon: (firstVertices, secondVertices, expansion = 0) ->
    firstOrientation = @getOrientation(firstVertices)
    for index in [0...firstVertices.length]
      return false if @allPointsOutsideEdge(firstVertices, firstOrientation, secondVertices, index, expansion)
    secondOrientation = @getOrientation(secondVertices)
    for index in [0...secondVertices.length]
      return false if @allPointsOutsideEdge(secondVertices, secondOrientation, firstVertices, index, expansion)
    true
  
  # Checks for a collision between the described polygon and path segment.
  @getPathSegmentCollision: (vertices, radius, start, end, reflectivity) ->
    orientation = @getOrientation(vertices)
    outsideLastLast = @isOutsideEdge(vertices, orientation, start, vertices.length - 2)
    outsideLast = @isOutsideEdge(vertices, orientation, start, vertices.length - 1)
    for index in [0...vertices.length]
      outside = @isOutsideEdge(vertices, orientation, start, index)
      if outsideLast
        if outside
          firstCollision = LineSegment.getPathSegmentCollision(vertices[(index + vertices.length - 1) % vertices.length],
            vertices[index], radius, start, end, reflectivity)
          secondCollision = LineSegment.getPathSegmentCollision(vertices[index], vertices[(index + 1) % vertices.length],
            radius, start, end, reflectivity)
          return firstCollision unless secondCollision?
          return secondCollision unless firstCollision?
          return (if firstCollision[0] < secondCollision[0] then firstCollision else secondCollision)
        else unless outsideLastLast
          return LineSegment.getPathSegmentCollision(vertices[(index + vertices.length - 1) % vertices.length],
            vertices[index], radius, start, end, reflectivity)
      outsideLastLast = outsideLast
      outsideLast = outside
    undefined
  
  # Find the penetration vector for the specified polygon and circle.
  @getPenetrationVector: (vertices, center, radius) ->
    Circle.getPenetrationVector(Polygon.getClosestPoint(vertices, center), center, radius)
  
  # Returns the orientation of the described polygon (+1 for CW, -1 for CCW)
  @getOrientation: (vertices) ->
    for index in [0...vertices.length]
      a = vertices[index]
      b = vertices[(index + 1) % vertices.length]
      c = vertices[(index + 2) % vertices.length]
      crossProduct = (b.x - a.x) * (c.y - b.y) - (c.x - b.x) * (b.y - a.y)
      if crossProduct > 0 then return 1
      else if crossProduct < 0 then return -1
    1
  
  # Checks whether the specified point is outside the indexed edge.
  @isOutsideEdge: (vertices, orientation, point, index) ->
    start = vertices[index]
    end = vertices[(index + 1) % vertices.length]
    crossProduct = (point.x - start.x) * (end.y - start.y) - (end.x - start.x) * (point.y - start.y)
    return orientation * crossProduct > 0
    
  constructor: (@vertices = [ new Point(), new Point(), new Point() ]) ->
    super 0
  
  # Sets the polygon's vertices.
  setVertices: (vertices) ->
    @vertices = vertices
    @updateBounds true
  
  clone: (feature = undefined) ->
    feature ?= new Polygon()
    feature.setVertices @vertices
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "Polygon" }
    json.vertices = (vertex.toJSON() for vertex in @vertices)
    super json
  
  fromJSON: (json) ->
    @setVertices (Point.fromJSON(vertex) for vertex in json.vertices)
    super json
    
  translate: (x, y) ->
    @setVertices (vertex.translated(x, y) for vertex in @vertices)
  
  rotate: (x, y, angle) ->
    @setVertices (vertex.rotated(x, y, angle) for vertex in @vertices)
  
  scale: (x, y, amount) ->
    @setVertices (vertex.scaled(x, y, amount) for vertex in @vertices)
  
  updateBounds: (forceDirty = false) ->
    expansion = Math.ceil(@lineWidth / 2) + 1 + (if @highlightColor? then Feature.HIGHLIGHT_SIZE else 0)
    @setBounds Polygon.getBounds(@vertices, expansion).roundUp(), forceDirty

  drawPath: (ctx, dirtyRegions) ->
    ctx.moveTo @vertices[0].x, @vertices[0].y
    for index in [1...@vertices.length]
      ctx.lineTo @vertices[index].x, @vertices[index].y
    ctx.lineTo @vertices[0].x, @vertices[0].y
    
  getSnapPoints: (point, edges = false) ->
    return @vertices unless edges
    closestDistance = Number.MAX_VALUE
    for index in [0...@vertices.length]
      featurePoint = LineSegment.getClosestPoint(@vertices[index], @vertices[(index + 1) % @vertices.length], point)
      distance = featurePoint.distance(point)
      if distance < closestDistance
        closestDistance = distance
        closestPoint = featurePoint
    [ closestPoint ]
  
  setSnapPoint: (index, point) ->
    vertices = @vertices[...]
    vertices[index] = point
    @setVertices vertices
    
  intersectsCircle: (center, radius) ->
    Polygon.getClosestPoint(@vertices, center).distance(center) < radius + @getStrokeRadius()

  intersectsPolygon: (vertices) ->
    Polygon.intersectsPolygon(@vertices, vertices, @getStrokeRadius())
  
  getPathSegmentCollision: (puck, prediction, start, end) ->
    return undefined unless @collidable
    Polygon.getPathSegmentCollision(@vertices, @getStrokeRadius() + puck.getExpandedRadius(), start, end, @reflectivity)

  getPenetrationVector: (puck) ->
    return undefined unless @collidable
    Polygon.getPenetrationVector(@vertices, puck.center, @getStrokeRadius() + puck.getExpandedRadius())

  # Checks whether all of the points specified are outside the described edge.
  @allPointsOutsideEdge: (vertices, orientation, points, index, expansion) ->
    start = vertices[index]
    end = vertices[(index + 1) % vertices.length]
    edgeX = end.x - start.x
    edgeY = end.y - start.y
    length = Math.sqrt(edgeX * edgeX + edgeY * edgeY)
    return false if length == 0
    scale = orientation / length
    edgeX *= scale
    edgeY *= scale
    for point in points
      return false if (point.x - start.x) * edgeY - edgeX * (point.y - start.y) < expansion
    true
    
    
# A text string feature.
class root.TextFeature extends FilledFeature
  constructor: (@translation = new Point(), @rotation = 0, @text = "") ->
    super 0
    @fontSize = 10
    @fontFamily = "sans-serif"
    @updateBounds()
  
  # Sets the position at which to draw the text.
  setPosition: (translation, rotation = 0) ->
    @translation = translation
    @rotation = rotation
    @updateBounds true
  
  # Sets the text to display.
  setText: (text) ->
    @text = text
    @updateBounds true
  
  # Sets the size of the font to use.
  setFontSize: (size) ->
    @fontSize = size
    @updateBounds true
  
  # Sets the font family to use.
  setFontFamily: (family) ->
    @fontFamily = family
    @updateBounds true
  
  translate: (x, y) ->
    @setPosition @translation.translated(x, y), @rotation
    
  rotate: (x, y, angle) ->
    @setPosition @translation.rotated(x, y, angle), @rotation + angle
  
  scale: (x, y, amount) ->
    @setPosition @translation.scaled(x, y, amount), @rotation
  
  clone: (feature = undefined) ->
    feature ?= new TextFeature()
    feature.setPosition @translation, @rotation
    feature.setText @text
    feature.setFontSize @fontSize
    feature.setFontFamily @fontFamily
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "TextFeature" }
    json.translation = @translation.toJSON()
    json.rotation = @rotation
    json.text = @text
    json.fontSize = @fontSize
    json.fontFamily = @fontFamily
    StrokedFeature.ctx.font = @getFont()
    json.width = StrokedFeature.ctx.measureText(@text).width
    super json
  
  fromJSON: (json) ->
    @setPosition Point.fromJSON(json.translation), json.rotation
    @setText json.text if json.text?
    @setFontSize json.fontSize if json.fontSize?
    @setFontFamily json.fontFamily if json.fontFamily?
    super json
    
  draw: (ctx, dirtyRegions) ->
    if @highlightColor?
      ctx.strokeStyle = @highlightColor
      ctx.lineWidth = Feature.HIGHLIGHT_SIZE * 2
      ctx.lineCap = "round"
      ctx.globalAlpha = 1
      ctx.beginPath()
      ctx.moveTo @vertices[0].x, @vertices[0].y
      for index in [1...@vertices.length]
        ctx.lineTo @vertices[index].x, @vertices[index].y
      ctx.lineTo @vertices[0].x, @vertices[0].y
      ctx.stroke()
    ctx.translate @translation.x, @translation.y
    ctx.rotate @rotation
    ctx.font = @getFont()
    ctx.textAlign = "center"
    ctx.textBaseline = "middle" 
    if @fillStyle.style?
      ctx.fillStyle = @fillStyle.style
      ctx.globalAlpha = @fillAlpha
      ctx.fillText @text, 0, 0
    if @strokeStyle.style?
      ctx.strokeStyle = @strokeStyle.style
      ctx.lineWidth = @lineWidth
      ctx.lineCap = @lineCap
      ctx.globalAlpha = @strokeAlpha
      ctx.strokeText @text, 0, 0
    ctx.rotate -@rotation
    ctx.translate -@translation.x, -@translation.y
    
  updateBounds: (forceDirty = false) ->
    StrokedFeature.ctx.font = @getFont()
    width = StrokedFeature.ctx.measureText(@text).width
    left = @translation.x - width / 2
    top = @translation.y - @fontSize / 2
    right = @translation.x + width / 2
    bottom = @translation.y + @fontSize / 2
    @vertices = [
      new Point(left, top).rotated(@translation.x, @translation.y, @rotation)
      new Point(right, top).rotated(@translation.x, @translation.y, @rotation)
      new Point(right, bottom).rotated(@translation.x, @translation.y, @rotation)
      new Point(left, bottom).rotated(@translation.x, @translation.y, @rotation)
    ]
    expansion = Math.ceil(@lineWidth / 2) + 1 + (if @highlightColor? then Feature.HIGHLIGHT_SIZE else 0)
    @setBounds Polygon.getBounds(@vertices, expansion).roundUp(), forceDirty
  
  # Returns the font described by the feature's properties.
  getFont: ->
    "#{@fontSize}px #{@fontFamily}"
  
  getSnapPoints: (point, edges = false) ->
    [ @translation ]
  
  setSnapPoint: (index, point) ->
    @setPosition point, @rotation
    
  intersectsCircle: (center, radius) ->
    Polygon.getClosestPoint(@vertices, center).distance(center) < radius + @lineWidth / 2
  
  intersectsPolygon: (vertices) ->
    Polygon.intersectsPolygon(@vertices, vertices, @lineWidth / 2)

    
# A puck feature.
class root.Puck extends Circle
  # The radius of the pucks.
  @RADIUS: 20
  
  # The proportional size of the handle on the controlled puck.
  @HANDLE_SIZE: 0.2
  
  # Semi-sane limit on number of iterations when predicting.
  @MAX_PREDICTION_ITERATIONS: 20

  # Semi-sane limit on number of iterations when depenetrating.
  @MAX_DEPENETRATION_ITERATIONS: 10

  # The point at which we accept that we've stopped when predicting.
  @PREDICTION_THRESHOLD: 0.1
  
  # The acceleration due to friction.
  @FRICTION_ACCELERATION: -0.375
    
  # A small threshold value.
  @EPSILON: 0.01

  # The available puck colors.
  @COLORS: [ "red", "orange", "yellow", "green", "blue", "indigo", "violet", "cyan",
    "magenta", "brown", "chartreuse", "silver", "tan", "coral", "gray", "royalblue" ]
  
  # The size of the puck icons.
  @ICON_SIZE: 16
  
  # Returns the icon URL for a puck of the specified color/controlled status.
  @getIconURL: (color, controlled = false) ->
    key = color + (if controlled then "_c" else "")
    url = @iconURLs[key]
    unless url?
      StrokedFeature.canvas.width = @ICON_SIZE
      StrokedFeature.canvas.height = @ICON_SIZE
      StrokedFeature.ctx.clearRect(0, 0, @ICON_SIZE, @ICON_SIZE)
      StrokedFeature.ctx.beginPath()
      halfSize = @ICON_SIZE / 2
      StrokedFeature.ctx.arc(halfSize, halfSize, halfSize * 0.9, 0, Math.PI * 2)
      StrokedFeature.ctx.fillStyle = color
      StrokedFeature.ctx.fill()
      StrokedFeature.ctx.stroke()
      if controlled
        StrokedFeature.ctx.beginPath()
        StrokedFeature.ctx.arc(halfSize, halfSize, halfSize * @HANDLE_SIZE * 0.9, 0, Math.PI * 2)
        StrokedFeature.ctx.fillStyle = "#000000"
        StrokedFeature.ctx.fill()
      @iconURLs[key] = url = StrokedFeature.canvas.toDataURL()
    url
  
  constructor: (@playfield, @translation = new Point(), @color = Puck.COLORS[0], @playerId = undefined) ->
    super @translation, Puck.RADIUS
    @mousable = true
    @setZOrder 1
    @setStrokeStyle new Style("#000000")
    @setLineWidth 3
    @setFillStyle new Style(@color)
    @nextArrows = []
    @debug = false
  
  # Sets the puck's position.
  setPosition: (translation) ->
    @translation = translation
    @setParameters translation, Puck.RADIUS
    @updatePerformingAction()
 
  # Sets the puck's color.
  setColor: (color) ->
    @setFillStyle new Style(@color = color)
 
  # Returns the (data) URL of the puck's icon.
  getIconURL: ->
    Puck.getIconURL @color, @isControlled()  
 
  # Initializes the puck's simulation state.
  initSimulation: ->
    @stepCount = 0
    @lastCollisionFeature = undefined
    @queue = @getMoves()
    @removeAction()
    @removeRest()
    @startNextMove()
    
  # Performs a simulation step.  Returns true if still simulating.
  stepSimulation: ->
    @stepCount++
    return false if @finishOrder?
    return false unless @moveStart? || (@performingAction? && @performingAction.pause) || @startNextMove()
    if @performingAction?
      if @performingAction.pause
        unless @performingAction.step(this)
          @setPerformingAction undefined
          return @startNextMove()
        return true
      else
        @performingAction.step(this)
    @elapsedTime++
    if @elapsedTime < @getMoveTime()
      totalDistance = @moveStart.distance(@moveEnd)
      distance = @elapsedTime * @elapsedTime * Puck.FRICTION_ACCELERATION / 2 + @elapsedTime *
        Math.sqrt(-2 * totalDistance * Puck.FRICTION_ACCELERATION)
      @stepTo Point.interpolate(@moveStart, @moveEnd, distance / totalDistance) 
    else
      @stepTo @moveEnd
    @depenetrate()
    return false if @finishOrder?
    unless @moveStart? && @elapsedTime < @getMoveTime()
      return @startNextMove()
    true    
  
  # Resolves any penetration issues.
  depenetrate: ->
    for iteration in [0...Puck.MAX_DEPENETRATION_ITERATIONS]
      features = @playfield.base.getFeaturesIntersectingCircle(@center, @getExpandedRadius())
      break if features.length == 0
      longestPenetration = null
      longestPenetrationLength = -1
      for feature in features
        penetration = feature.getPenetrationVector(this)
        if penetration?
          penetrationLength = penetration.length()
          if penetrationLength > longestPenetrationLength
            longestPenetrationLength = penetrationLength
            longestPenetration = penetration
      if longestPenetration?
        if @debug
          console.log "#{@playerId} #{@stepCount} resolving penetration #{longestPenetration.x} #{longestPenetration.y}"
        @translate(longestPenetration.x, longestPenetration.y)
  
  # Steps to the given translation, adjusting movement parameters to deal with collisions.
  stepTo: (translation) ->
    collision = @getClosestCollision false, @translation, translation
    unless collision?
      if @debug
        console.log "#{@playerId} #{@stepCount} move #{translation.x} #{translation.y}"
      @setPosition translation
      return
    @lastCollisionFeature = collision[2]
    contact = Point.interpolate(@translation, translation, collision[0])
    expectedReflectionDistance = @translation.distance(translation) - @translation.distance(contact)
    if @debug
      console.log "#{@playerId} #{@stepCount} collision #{collision[0]} #{collision[1].x} " +
        "#{collision[1].y} #{@lastCollisionFeature.toJSON().type}"
    @setPosition collision[1]
    if collision[2].constructor == @constructor
      @handlePuckCollision collision[2]
      return
    if collision[2].constructor == LineSegment && collision[2].role == "finish-line"
      @setVisible false
      @setCollidable false
      @finishOrder = 0
      return 
    reflectionDistance = contact.distance(@translation)
    if reflectionDistance < Puck.EPSILON
      @moveStart = undefined
      return
    reflectionRatio = reflectionDistance / expectedReflectionDistance
    nx = (@translation.x - contact.x) / reflectionDistance
    ny = (@translation.y - contact.y) / reflectionDistance
    contactDistance = @moveStart.distance(contact)
    remainingDistance = @moveStart.distance(@moveEnd) - contactDistance
    @moveEnd.x = contact.x + reflectionRatio * remainingDistance * nx
    @moveEnd.y = contact.y + reflectionRatio * remainingDistance * ny
    t2 = @elapsedTime * @elapsedTime
    remainingDistance = contact.distance(@moveEnd)
    x = remainingDistance + t2 * Puck.FRICTION_ACCELERATION / 2
    b = 2 * Puck.FRICTION_ACCELERATION * t2 - 2 * x
    c = x * x
    totalDistance = (-b + Math.sqrt(b*b - 4*c)) / 2
    contactDistance = totalDistance - remainingDistance
    @moveStart.x = contact.x - contactDistance * nx
    @moveStart.y = contact.y - contactDistance * ny
 
  # Handles a collision between two (potentially) moving pucks.  See
  # http://en.wikipedia.org/wiki/Elastic_collision#Two-Dimensional_Collision_With_Two_Moving_Objects
  handlePuckCollision: (puck) ->
    v1 = @getVelocity()
    v2 = puck.getVelocity()
    cx = @center.x - puck.center.x
    cy = @center.y - puck.center.y
    lengthSquared = cx*cx + cy*cy
    vx = v1.x - v2.x
    vy = v1.y - v2.y
    product = (cx*vx + cy*vy) / lengthSquared
    dx = product * cx
    dy = product * cy
    @setVelocity(new Point(v1.x - dx, v1.y - dy))
    puck.setVelocity(new Point(v2.x + dx, v2.y + dy))
    
  # Sets the puck's current velocity.
  setVelocity: (velocity) ->
    length = velocity.length()
    if length < Puck.EPSILON
      @moveStart = undefined
      return
    @moveStart = @translation
    scale = length / (-2 * Puck.FRICTION_ACCELERATION)
    @moveEnd = new Point(@moveStart.x + velocity.x * scale, @moveStart.y + velocity.y * scale)
    @elapsedTime = 0
    @setPerformingAction undefined
  
  # Returns the puck's current velocity.
  getVelocity: ->
    return new Point() unless @moveStart?
    totalDistance = @moveStart.distance(@moveEnd)
    speed = Math.max(0, Math.sqrt(-2 * totalDistance * Puck.FRICTION_ACCELERATION) +
      @elapsedTime * Puck.FRICTION_ACCELERATION)
    return new Point() if speed == 0
    scale = speed / totalDistance
    new Point((@moveEnd.x - @moveStart.x) * scale, (@moveEnd.y - @moveStart.y) * scale)
  
  # Returns the total time for the current move.
  getMoveTime: ->
    Math.sqrt(-2 * @moveStart.distance(@moveEnd) / Puck.FRICTION_ACCELERATION)
  
  # Sets up the next move in the queue, if any.  Returns whether a move was started.
  startNextMove: ->
    @setPerformingAction undefined
    while @queue.length > 0     
      move = @queue.shift()
      if move.perform?
        move.perform this
        @setPerformingAction move
        if move.pause
          @moveStart = undefined
          return true
      else
        @moveStart = @translation
        @moveEnd = new Point(@moveStart.x + move.x, @moveStart.y + move.y)
        @elapsedTime = 0
        return true
    @setPerformingAction undefined
    @moveStart = undefined
    false
  
  # Sets the action being performed.
  setPerformingAction: (action) ->
    if @performingAction?
      @playfield.base.removeFeature @performingAction.feature
    @performingAction = action
    if @performingAction?
      @playfield.base.addFeature @performingAction.feature
      @updatePerformingAction()
  
  # Updates the state of the action being performed.
  updatePerformingAction: ->
    return unless @performingAction?
    @performingAction.feature.setPosition @getActionPosition()
    @performingAction.feature.setVisible @visible
  
  # Returns the list of moves associated with this puck.
  getMoves: ->
    moves = []
    moves.push @move if @move?
    moves.push @action if @action?
    return moves unless @nextPuck?
    moves.concat @nextPuck.getMoves()
 
  # Sets the listener to notify when moves change.
  setMoveListener: (listener) ->
    @moveListener = listener
    @nextPuck.setMoveListener(listener) if @nextPuck?
  
  # Sets the move distances.
  setMoveDistances: (distances) ->
    @moveDistances = distances
  
  # Removes the puck and all of its associated features.
  removeAll: ->
    @removeAction()
    @removeRest()
    @playfield.base.removeFeature this
 
  # Removes all of the associated features after this puck.
  removeRest: ->
    if @nextPuck?
      @nextPuck.removeAll()
      @nextPuck = undefined
    @playfield.base.removeFeature arrow for arrow in @nextArrows
    @nextArrows = []
    @moveListener() if @moveListener?
  
  # Returns the last puck in the chain.
  getLastPuck: ->
    if @nextPuck? then @nextPuck.getLastPuck() else this
  
  # Checks whether the local player controls this puck.
  isControlled: ->
    @playerId == @playfield.playerId
  
  # Adds the action on the last puck in sequence.
  addAction: (action) ->
    if @nextPuck?
      @nextPuck.addAction action
    else
      @removeAction()
      @action = action
      @action.feature.setPosition @getActionPosition()
      @playfield.base.addFeature @action.feature
      @action.apply(this)
  
  # Returns the location at which to render an action.
  getActionPosition: ->
    new Point(@center.x + @radius * 1.2, @center.y - @radius * 1.2).rounded()
  
  # Sets the object to notify when actions are removed.
  setActionRemovalListener: (listener) ->
    @actionRemovalListener = listener
    @nextPuck.setActionRemovalListener(listener) if @nextPuck?
  
  # Removes the set action, if any.
  removeAction: ->
    if @action?
      @action.revert this
      @playfield.base.removeFeature @action.feature
      @actionRemovalListener(@action) if @actionRemovalListener?
      @action = null
  
  setVisible: (visible) ->
    super visible
    @updatePerformingAction()
  
  setClickHandler: (handler) ->
    @clickHandler = handler
    @nextPuck.setClickHandler(handler) if @nextPuck?
  
  setPlayfield: (playfield) ->
    @removeRest()
    @playfield = playfield
    nextQueue = @queue[...]
    while nextQueue.length > 0
      move = nextQueue.shift()
      if move.perform?
        @addAction move
      else
        @nextPuck = new Puck(@playfield, @translation, @color, @playerId)
        @nextPuck.setZOrder 2 if @isControlled()
        @nextPuck.setFillStyle new Style(null)
        @updateNextPuck(@nextArrows, @nextPuck, move, @playfield.base, 1.0)
        @nextPuck.queue = nextQueue
        @nextPuck.setPlayfield @playfield
        @playfield.base.addFeature @nextPuck
        return
  
  translate: (x, y) ->
    @setPosition @translation.translated(x, y)
    if @moveStart?
      @moveStart = @moveStart.translated(x, y)
      @moveEnd = @moveEnd.translated(x, y)
    
  clone: (feature = undefined) ->
    feature ?= new Puck()
    feature.setColor @color
    feature.setPosition @translation
    feature.playerId = @playerId
    feature.queue = @queue
    super feature
  
  toJSON: (json = undefined) ->
    json ?= { type: "Puck" }
    json.color = @color
    json.translation = @translation.toJSON()
    json.playerId = @playerId
    json.queue = (move.toJSON() for move in @queue)
    json.finishOrder = @finishOrder
    super json
  
  fromJSON: (json) ->
    @setColor json.color if json.color?
    @setPosition Point.fromJSON(json.translation)
    @playerId = json.playerId
    @queue = ((if move.type? then PuckAction.fromJSON(move) else Point.fromJSON(move)) for move in json.queue)
    @finishOrder = json.finishOrder
    super json
    @setVisible(false) if @finishOrder?
    
  draw: (ctx, dirtyRegions) ->
    # tweak for highlights on transparent pucks
    unless @highlightColor? && !@fillStyle.style?
      super ctx, dirtyRegions
      @drawHandle(ctx) if @isControlled()
      return  
    ctx.beginPath()
    ctx.arc @center.x, @center.y, @radius + Feature.HIGHLIGHT_SIZE, 0, Math.PI * 2
    ctx.strokeStyle = @highlightColor
    ctx.lineWidth = @lineWidth / 2 + Feature.HIGHLIGHT_SIZE
    ctx.lineCap = "round"
    ctx.globalAlpha = 1
    ctx.stroke()
    ctx.beginPath()
    @drawPath ctx, dirtyRegions
    @drawStroke(ctx) if @strokeStyle.style?
    @drawHandle(ctx) if @isControlled()
  
  drawHandle: (ctx) ->
    ctx.beginPath()
    ctx.arc @center.x, @center.y, @radius * Puck.HANDLE_SIZE, 0, Math.PI * 2
    ctx.fillStyle = "#000000"
    ctx.globalAlpha = @strokeAlpha
    ctx.fill()   
      
  mousedown: ->
    if @clickHandler?
      super()
      return
    if @moveDistances? && @moveDistances.length == 0
      @playfield.setMouseFeature @previousPuck
      @previousPuck.mousedown() # will remove this puck
      return
    $("#overlay-layer").css "cursor", "crosshair"
    @removeRest()
    @placingNextPuck = new Puck(@playfield, @translation, @color, @playerId)
    @placingNextPuck.setZOrder 2 if @isControlled()
    @placingNextPuck.setFillStyle new Style(null)
    if @moveDistances?
      @placingNextPuck.setMoveDistances @moveDistances.slice(1)
      @placingNextPuck.previousPuck = this
    @playfield.overlay.addFeature @placingNextPuck
    @placingNextArrows = []
    @updatePlacingNextPuck()
    @placingListener(true) if @placingListener?
  
  mouseup: ->
    if @clickHandler?
      super()
      return
    $("#overlay-layer").css "cursor", "default"
    return unless @placingNextPuck?
    @playfield.overlay.removeFeature @placingNextPuck
    @playfield.overlay.removeFeature arrow for arrow in @placingNextArrows
    position = @playfield.base.getLayerPosition @placingNextPuck.translation, @playfield.overlay
    if position.distance(@translation) >= Puck.RADIUS
      @nextPuck = @placingNextPuck
      @nextPuck.setPosition position
      @nextPuck.setStrokeAlpha 1
      @nextPuck.setMoveListener @moveListener
      @nextPuck.setActionRemovalListener @actionRemovalListener
      @playfield.base.addFeature @nextPuck
      for arrow in @placingNextArrows
        @nextArrows.push arrow
        arrow.setEndpoints @playfield.base.getLayerPosition(arrow.start, @playfield.overlay),
          @playfield.base.getLayerPosition(arrow.end, @playfield.overlay)
        arrow.setStrokeAlpha 1
        @playfield.base.addFeature arrow
      @moveListener() if @moveListener?
    else
      @removeAction()
    @placingNextPuck = undefined
    @placingNextArrows = undefined
    @placingListener(false) if @placingListener?
  
  mousemove: ->
    @updatePlacingNextPuck() if @placingNextPuck?
  
  getPathSegmentCollision: (puck, prediction, start, end) ->
    return undefined if prediction || puck == this
    super puck, prediction, start, end
  
  getPenetrationVector: (puck) ->
    return undefined if puck == this
    super puck
    
  # Updates the next puck display.
  updatePlacingNextPuck: ->
    @playfield.overlay.removeFeature arrow for arrow in @placingNextArrows
    @placingNextArrows = []
    mousePosition = @playfield.base.getWorldPosition @playfield.mouseClientX, @playfield.mouseClientY
    move = new Point(mousePosition.x - @translation.x, mousePosition.y - @translation.y)
    if @moveDistances? && move.length() > @moveDistances[0]
      move = move.scaled(0, 0, @moveDistances[0] / move.length())
    @updateNextPuck(@placingNextArrows, @placingNextPuck, move, @playfield.overlay, 0.5)
  
  # Updates the next puck display.
  updateNextPuck: (nextArrows, nextPuck, move, layer, alpha) ->
    path = @predictPath move
    layerPath = layer.getLayerPositions path, @playfield.base
    initialPosition = layer.getLayerPosition @translation, @playfield.base
    finalPosition = layerPath[layerPath.length - 1]
    expandedRadius = Puck.RADIUS + @lineWidth / 2 + 1
    for index in [0...layerPath.length - 1]
      start = layerPath[index]
      end = layerPath[index + 1]
      # clip against initial and final positions  
      if start.distance(initialPosition) < expandedRadius
        continue if end.distance(initialPosition) < expandedRadius
        start = LineSegment.getCircleIntersection(start, end, initialPosition, expandedRadius)
      arrow = false
      if end.distance(finalPosition) < expandedRadius
        continue if start.distance(finalPosition) < expandedRadius
        end = LineSegment.getCircleIntersection(start, end, finalPosition, expandedRadius)
        arrow = true
      segment = new (if arrow then Arrow else LineSegment)(start, end)
      segment.setZOrder 1
      segment.setCollidable false
      segment.setLineWidth 3
      segment.setStrokeAlpha alpha
      layer.addFeature segment
      nextArrows.push segment
    nextPuck.setPosition layerPath[path.length - 1]
    nextPuck.setStrokeAlpha alpha * Math.min(path[path.length - 1].distance(@translation) / Puck.RADIUS, 1)
    nextPuck.move = move
  
  # Predicts the path that this puck will take with the given movement vector.
  predictPath: (move) ->
    path = [ @translation ]
    end = new Point(@translation.x + move.x, @translation.y + move.y)
    @lastCollisionFeature = undefined
    for iteration in [0...Puck.MAX_PREDICTION_ITERATIONS]
      start = path[path.length - 1]
      closestCollision = @getClosestCollision true, start, end
      unless closestCollision?
        path.push end
        break
      newStart = Point.interpolate(start, end, closestCollision[0])
      path.push newStart
      if newStart.distance(closestCollision[1]) < Puck.PREDICTION_THRESHOLD
        break
      @lastCollisionFeature = closestCollision[2]
      end = closestCollision[1]
    path
  
  # Finds and returns the first collision for this puck on the specified travel segment.
  getClosestCollision: (prediction, start, end) ->
    expandedRadius = @getExpandedRadius()
    minX = Math.min(start.x, end.x) - expandedRadius
    minY = Math.min(start.y, end.y) - expandedRadius
    bounds = new Rectangle(minX, minY,
      Math.max(start.x, end.x) - minX + expandedRadius,
      Math.max(start.y, end.y) - minY + expandedRadius)
    closestCollision = undefined
    @playfield.base.visitFeaturesIntersecting bounds, (feature) =>
      collision = feature.getPathSegmentCollision this, prediction, start, end
      if collision? && (!closestCollision? || collision[0] < closestCollision[0])
        closestCollision = collision
        closestCollision.push feature 
    closestCollision
  
  # The icon URL hash.
  @iconURLs: {} 
    

# Base class for puck actions.
class root.PuckAction
  # Creates an action from its JSON representation.
  @fromJSON: (json) ->
    action = new root[json.type]()
    action.fromJSON(json)
    action

  constructor: (name, glyphicon, icon, pause = false) ->
    @index = -1
    @label = "<span class='#{glyphicon}'></span> #{name}"
    @feature = new ImageFeature(new Point(), 0, "/assets/" + icon + ".png")
    @feature.collidable = false
    @feature.setZOrder 1
    @pause = pause
  
  # Initializes this action from its JSON representation.
  fromJSON: (json) ->

  # Returns the JSON representation of the action.
  toJSON: ->
    @index

  # Applies the action to the specified puck (during move input).
  apply: (puck) ->
  
  # Reverts the action on the specified puck (during move input).
  revert: (puck) ->

  # Performs the action (during simulation).
  perform: (puck) ->
  
  # Steps the action (during simulation).
  step: (puck) ->
  

# An action that increases the next move distance.
class root.Boost extends PuckAction
  constructor: ->  
    super "Boost", "glyphicon glyphicon-forward", "boost"
    @amount = 0.5
  
  fromJSON: (json) ->
    @amount = json.amount if json.amount?
    super json
    
  apply: (puck) ->
    if puck.moveDistances? && puck.moveDistances.length > 0
      puck.moveDistances[0] *= (1 + @amount)
  
  revert: (puck) ->
    if puck.moveDistances? && puck.moveDistances.length > 0
      puck.moveDistances[0] /= (1 + @amount)


# An action that provides an extra move.
class root.Extra extends PuckAction
  constructor: ->  
    super "Extra", "glyphicon glyphicon-plus", "extra"
    @distance = 150
  
  fromJSON: (json) ->
    @distance = json.distance if json.distance?
    super json
  
  apply: (puck) ->
    puck.moveDistances.unshift(@distance) if puck.moveDistances?
    puck.moveListener() if puck.moveListener?
  
  revert: (puck) ->
    puck.moveDistances.shift() if puck.moveDistances?
    puck.moveListener() if puck.moveListener?
    

# An action that splits the next move into two parts.
class root.Split extends PuckAction
  constructor: ->  
    super "Split", "glyphicon glyphicon-scissors", "split"
    
  apply: (puck) ->
    if puck.moveDistances? && puck.moveDistances.length > 0
      distance = puck.moveDistances.shift() / 2.0
      puck.moveDistances.unshift(distance)
      puck.moveDistances.unshift(distance)  
    puck.moveListener() if puck.moveListener?
  
  revert: (puck) ->
    if puck.moveDistances? && puck.moveDistances.length > 1
      distance = puck.moveDistances.shift() + puck.moveDistances.shift()
      puck.moveDistances.unshift(distance)
    puck.moveListener() if puck.moveListener?
    

# An action that pauses the puck for a split-second.
class root.Pause extends PuckAction
  constructor: ->  
    super "Pause", "glyphicon glyphicon-time", "pause", true
    @steps = 30
  
  fromJSON: (json) ->
    @steps = json.steps if json.steps?
    super json
    
  perform: (puck) ->  
    puck.pauseStepsRemaining = @steps
  
  step: (puck) ->
    (puck.pauseStepsRemaining -= 1) > 0
  
    
# An action that pushes other pucks away.
class root.Push extends PuckAction
  constructor: ->  
    super "Push", "glyphicon glyphicon-resize-horizontal", "push"
    @amount = 1
    
  fromJSON: (json) ->
    @amount = json.amount if json.amount?
    super json

  perform: (puck) ->
      
        
# An action that draws all other pucks towards this one.
class root.Pull extends PuckAction
  # The maximum step size.
  @MAX_STEP_SIZE: 10
  
  constructor: ->  
    super "Pull", "glyphicon glyphicon-heart", "pull", true
    @steps = 30
    @amount = 0.05
    
  fromJSON: (json) ->
    @steps = json.steps if json.steps?
    @amount = json.amount if json.amount?
    super json

  perform: (puck) ->
    puck.pauseStepsRemaining = @steps
  
  step: (puck) ->
    return false if (puck.pauseStepsRemaining -= 1) <= 0
    for feature in puck.playfield.simulationFeatures
      continue if feature.constructor != Puck || feature == puck
      vector = puck.translation.subtracted(feature.translation)
      vector.scale(@amount)
      length = vector.length()
      if length > Pull.MAX_STEP_SIZE
        vector.scale(Pull.MAX_STEP_SIZE / length)
      feature.translate(vector.x, vector.y)
      feature.depenetrate()
    true
  
  
# An action that scatters other pucks randomly.
class root.Scatter extends PuckAction
  constructor: ->  
    super "Scatter", "glyphicon glyphicon-random", "scatter"
    @amount = 1
    
  fromJSON: (json) ->
    @amount = json.amount if json.amount?
    super json
    
  perform: (puck) ->
  
    
# An action that draws all other pucks towards this one.
class root.Shock extends PuckAction
  constructor: ->  
    super "Shock", "glyphicon glyphicon-flash", "shock"
    @amount = 1
    
  fromJSON: (json) ->
    @amount = json.amount if json.amount?
    super json

  perform: (puck) ->
      
    
# Combines a feature with its snap point index.
class root.FeatureSnapPoint
  constructor: (@feature, @index) ->

  # Sets the snap point to the given location.
  set: (point) ->
    @feature.setSnapPoint(@index, point)


# Represents a layer within the playfield.
class root.Layer
  constructor: (@playfield, canvasSelector) ->
    @translation = new Point
    @scale = 1.0
    @oversizedFeatures = []
    @canvas = $(canvasSelector).get(0)
    @ctx = @canvas.getContext "2d"
    @featureSpace = new HashSpace(@canvas.width, 8)
    @dirtyRegions = []
    @dirty()
    @lastAddOrder = 0
  
  # Adds a set of features to the layer, ignoring missing entries.
  addFeatures: (features) ->
    for feature in features
      @addFeature(feature) if feature?
      
  # Adds a feature to the layer.
  addFeature: (feature) ->
    return if feature.layer == this
    feature.layer.removeFeature(feature) if feature.layer?
    feature.layer = this
    feature.addOrder = ++@lastAddOrder unless feature.addOrder?
    @dirty feature.bounds
    if feature.bounds?
      @featureSpace.add feature, feature.bounds
    else
      @oversizedFeatures.push feature
  
  # Removes a set of features from the layer, ignoring missing entries.
  removeFeatures: (features) ->
    for feature in features
      @removeFeature(feature) if feature?
  
  # Removes a feature from the layer.
  removeFeature: (feature) ->
    return unless feature.layer == this
    feature.layer = undefined
    @dirty feature.bounds
    if feature.bounds?
      @featureSpace.remove feature, feature.bounds
    else
      index = @oversizedFeatures.indexOf feature
      @oversizedFeatures.splice(index, 1) unless index == -1
    
  # Sets the layer translation.
  setTranslation: (translation) ->
    # see if we can preserve part of the view by scrolling
    deltaX = (translation.x - @translation.x) / @scale
    deltaY = (translation.y - @translation.y) / @scale
    newScrollDestRect = @scrollDestRect.translated(-deltaX, -deltaY) if @scrollDestRect?
    newWindow = new Rectangle(0, 0, @canvas.width, @canvas.height)
    oldVisibleRegion = @getVisibleRegion()
    @translation = translation
    unless newScrollDestRect && newScrollDestRect.intersects(newWindow)  
      @dirty()
      return
    # adjust the scroll state
    intersection = newScrollDestRect.intersection(newWindow)
    @scrollSrcPos.x += intersection.x - newScrollDestRect.x
    @scrollSrcPos.y += intersection.y - newScrollDestRect.y
    @scrollDestRect = intersection
    
    # make sure we're going to update
    @ensureUpdateScheduled()
    
    # clip existing dirty regions to new visible region
    visibleRegion = @getVisibleRegion()
    newDirtyRegions = []
    for dirtyRegion in @dirtyRegions
      newDirtyRegions.push(dirtyRegion.intersection(visibleRegion)) if dirtyRegion.intersects(visibleRegion)
    @dirtyRegions = newDirtyRegions
    
    # add the exposed regions to the dirty list
    sideY = visibleRegion.y
    sideHeight = visibleRegion.height
    diffY = visibleRegion.y - oldVisibleRegion.y
    if diffY < 0
      @dirtyRegions.push(new Rectangle(visibleRegion.x, visibleRegion.y, visibleRegion.width, -diffY))
      sideY = oldVisibleRegion.y
      sideHeight += diffY
    else if diffY > 0
      @dirtyRegions.push(new Rectangle(visibleRegion.x, oldVisibleRegion.bottom(), visibleRegion.width, diffY))
      sideHeight -= diffY
    
    if visibleRegion.x < oldVisibleRegion.x
      @dirtyRegions.push(new Rectangle(visibleRegion.x, sideY, oldVisibleRegion.x - visibleRegion.x, sideHeight))
    else if visibleRegion.x > oldVisibleRegion.x
      @dirtyRegions.push(new Rectangle(oldVisibleRegion.right(), sideY, visibleRegion.x - oldVisibleRegion.x, sideHeight))
    
  # Sets the layer scale.
  setScale: (scale) ->
    @scale = scale
    @dirty()
  
  # Returns the layer's visible region.
  getVisibleRegion: ->
    new Rectangle(@translation.x, @translation.y, @canvas.width * @scale, @canvas.height * @scale)
  
  # Returns the layer (world) location corresponding to the given client position.
  getWorldPosition: (clientX, clientY) ->
    offset = $(@canvas).offset()
    new Point(@translation.x + (clientX - offset.left - @canvas.clientLeft) * @scale, @translation.y +
      (clientY - offset.top - @canvas.clientTop) * @scale)
  
  # Returns the layer location corresponding to the given (world) position in the specified layer.
  getLayerPosition: (position, layer) ->
    new Point(@translation.x + (position.x - layer.translation.x) * @scale / layer.scale,
      @translation.y + (position.y - layer.translation.y) * @scale / layer.scale)
  
  # Returns the layer locations corresponding to the given (world) positions in the specified layer.
  getLayerPositions: (positions, layer) ->
    @getLayerPosition(position, layer) for position in positions
  
  # Returns the layer distance corresponding to the given (world) distance in the specified layer.
  getLayerDistance: (distance, layer) ->
    distance * @scale / layer.scale
  
  # Finds the closest snap position to the position specified (within the given radius), or returns
  # undefined if one was not found.  The edges parameter indicates whether to include edges as well as vertices.
  # Any features in the exclude array will be ignored.
  getSnapPosition: (position, radius, edges, excludeFeatures = []) ->
    closest = undefined
    closestDistance = radius
    @visitFeaturesIntersecting new Rectangle(position.x - radius, position.y - radius, radius * 2, radius * 2), (feature) ->
      return if excludeFeatures.indexOf(feature) != -1
      for point in feature.getSnapPoints(position, edges)
        distance = point.distance(position)
        if distance <= closestDistance
          closest = point
          closestDistance = distance
    closest
  
  # Returns an array containing two items: an array with all FeatureSnapPoints at the closest snap position to
  # the given point within the radius, and the closest position itself.
  getFeatureSnapPointsAndLocation: (position, radius) ->
    closest = undefined
    closestDistance = radius
    snapPoints = []
    @visitFeaturesIntersecting new Rectangle(position.x - radius, position.y - radius, radius * 2, radius * 2), (feature) ->
      points = feature.getSnapPoints(position) 
      for index in [0...points.length]
        point = points[index]
        distance = point.distance(position)
        if distance < closestDistance
          closest = point
          closestDistance = distance
          snapPoints = [ new FeatureSnapPoint(feature, index) ]
        else if point.equals(closest)
          snapPoints.push new FeatureSnapPoint(feature, index)
    [ snapPoints, closest ]
  
  # Returns an array containing all features intersecting the described circle.
  getFeaturesIntersectingCircle: (center, radius) ->
    features = []
    @visitFeaturesIntersecting new Rectangle(center.x - radius, center.y - radius, radius * 2, radius * 2), (feature) ->
      features.push feature if feature.intersectsCircle(center, radius)
    features
 
  # Returns an array containing all of the (intersectable) features in the layer.
  getAllIntersectableFeatures: ->
    features = []
    @visitAllFeatures (feature) ->
      features.push feature if feature.bounds?
    features
  
  # Removes all intersectable features.
  removeAllIntersectableFeatures: ->
    @featureSpace.clear()
    @dirty()
  
  # Returns an array containing all features intersecting the described polygon.
  getFeaturesIntersectingPolygon: (vertices) ->
    features = []
    @visitFeaturesIntersecting Polygon.getBounds(vertices), (feature) ->
      features.push feature if feature.intersectsPolygon(vertices)
    features
  
  # Visits all features intersecting the specified region (including the oversized ones).
  visitFeaturesIntersecting: (region, visitor) ->
    visitor(feature) for feature in @oversizedFeatures
    @featureSpace.visitIntersecting(region, visitor)
  
  # Visits all features.
  visitAllFeatures: (visitor) ->
    visitor(feature) for feature in @oversizedFeatures
    @featureSpace.visitAll(visitor)
  
  # Dirties the described region.
  dirty: (region) ->
    # make sure we're going to update
    @ensureUpdateScheduled()
    
    # when called without arguments, dirty everything and reset
    visibleRegion = @getVisibleRegion()
    unless region?
      @dirtyRegions = [ visibleRegion ]
      @scrollDestRect = undefined
      @scrollSrcPos = undefined
      return
    
    # clip against visible region
    region = region.intersection(visibleRegion) unless visibleRegion.contains(region)
    
    # make sure it's not empty
    return if region.isEmpty()
    
    # while the region intersects any existing region, remove it and dirty the union
    until (index = @getIntersectingDirtyRegionIndex(region)) == -1
      region = region.union(@dirtyRegions[index])
      @dirtyRegions.splice index, 1
      
    # add the union region
    @dirtyRegions.push(region)
  
  # Ensures that an update is scheduled for the next frame.
  ensureUpdateScheduled: ->
    unless @dirtyRegions.length > 0
      if requestAnimationFrame?
        requestAnimationFrame => @update()
      else
        setTimeout((=> @update()), 0) 
  
  # Returns the index of the first dirty region intersecting the one specified, or -1 if none.
  getIntersectingDirtyRegionIndex: (region) ->
    for index in [0...@dirtyRegions.length]
      return index if @dirtyRegions[index].intersects(region)
    -1
    
  # Redraws all dirty regions.
  update: ->
    # apply scroll, if any
    @ctx.globalAlpha = 1
    if @scrollDestRect? && (@scrollSrcPos.x != @scrollDestRect.x || @scrollSrcPos.y != @scrollDestRect.y)
      @ctx.globalCompositeOperation = "copy"
      @ctx.drawImage @canvas, @scrollSrcPos.x, @scrollSrcPos.y, @scrollDestRect.width, @scrollDestRect.height,
        @scrollDestRect.x, @scrollDestRect.y, @scrollDestRect.width, @scrollDestRect.height
      @ctx.globalCompositeOperation = "source-over"
  
    # save state and apply the view transform
    @ctx.save()
    @ctx.setTransform 1 / @scale, 0, 0, 1 / @scale, -@translation.x / @scale, -@translation.y / @scale
    
    # clear the dirty regions
    for dirtyRegion in @dirtyRegions
      @ctx.clearRect dirtyRegion.x, dirtyRegion.y, dirtyRegion.width, dirtyRegion.height
    
    # clip to the dirty regions
    @ctx.beginPath()
    for dirtyRegion in @dirtyRegions
      @ctx.rect dirtyRegion.x, dirtyRegion.y, dirtyRegion.width, dirtyRegion.height
    @ctx.clip()
    
    # start with the oversized features, which are always in view
    features = @oversizedFeatures[...]
    
    # add the features intersecting the dirty regions
    pusher = (feature) -> features.push(feature)
    @featureSpace.visitIntersecting(dirtyRegion, pusher) for dirtyRegion in @dirtyRegions
    
    # sort the features
    features.sort Feature.SORT_FUNCTION
    
    # draw the features
    @ctx.translate 0.5, 0.5
    for feature in features
      feature.draw @ctx, @dirtyRegions if feature.visible && (feature.visibleInGame || !@playfield.gameModeEnabled)
    
    # restore the context
    @ctx.restore()
    
    # dirtiness resolved; note that we can scroll the entire window
    @dirtyRegions = []
    @scrollDestRect = new Rectangle(0, 0, @canvas.width, @canvas.height)
    @scrollSrcPos = new Point()


# Represents the area of play.
class root.Playfield
  # The target FPS for simulation.
  @FRAMES_PER_SECOND: 60

  # The proportion of the screen to allocate to the incoming path.
  @PATH_OFFSET: 0.2

  constructor: (@gameModeEnabled = true) ->
    @base = new Layer(this, "#base-layer")
    @base.addFeature(@grid = new Grid())
    @overlay = new Layer(this, "#overlay-layer")
    @backgroundColor = "#FFFFFF"
    @mouseClientX = 0
    @mouseClientY = 0
    @mouseDown = false
    $("#overlay-layer")
      .mousedown (event) => @mousedown(event)
      .mouseup (event) => @mouseup(event)
      .mouseenter (event) => @mouseenter(event)
      .mouseleave (event) => @mouseleave(event)
      .mousemove (event) => @mousemove(event)
    layer = $("#overlay-layer").get(0)
    layer.addEventListener "touchstart", (event) => @touchstart(event)
    layer.addEventListener "touchmove", (event) => @touchmove(event)
    layer.addEventListener "touchend", (event) => @touchend(event)
      
  # Enables or disables game mode.
  setGameModeEnabled: (enabled) ->
    @gameModeEnabled = enabled
    unless enabled
      $("#overlay-layer").css "cursor", "default"
      @clearLastPosition()
      @setMouseFeature undefined
      @mouseDown = false
      @stopSimulation()
    @base.dirty()
    @overlay.dirty()
  
  # Sets the id of the local player.
  setPlayerId: (playerId) ->
    @playerId = playerId
  
  # Sets the translation for both layers.
  setTranslation: (translation, interval = 0, finished = true) ->
    if interval == 0
      @base.setTranslation translation
      @overlay.setTranslation translation
      @translationListener(finished) if @translationListener?
      return
    start = @base.translation
    accumulated = 0
    stepper = =>
      accumulated += 1 / Playfield.FRAMES_PER_SECOND
      if accumulated >= interval
        clearInterval translator
        @setTranslation(translation)
      else
        t = accumulated / interval
        @setTranslation(Point.interpolate(start, translation, 2*t - t*t).rounded(), 0, false)
    translator = setInterval(stepper, 1000 / Playfield.FRAMES_PER_SECOND)
  
  # Centers the translation over the closet point on the path to the specified location.
  centerTranslationOnPath: (point, interval = 0) ->
    [ location, direction ] = @getPathLocationAndDirection(point)
    @setTranslation(new Point(
      location.x - @base.canvas.width * (0.5 - Math.cos(direction) * Playfield.PATH_OFFSET),
      location.y - @base.canvas.height * (0.5 - Math.sin(direction) * Playfield.PATH_OFFSET)).rounded(), interval)
  
  # Sets the playfield's background color.
  setBackgroundColor: (color) ->
    @backgroundColor = color
    $("#playfield").css "background-color", @backgroundColor
    
  # Sets the JSON representation of the playfield.
  setJSON: (json) ->
    json ?= { backgroundColor: "#FFFFFF", features: [], path: [] }
    @setBackgroundColor json.backgroundColor
    @grid.setVisible (json.showGrid ? true)
    @grid.setStrokeStyle new Style(json.gridColor ? "#D0D0D0")
    @grid.setSpacing (json.gridSpacing ? 40)
    @base.removeAllIntersectableFeatures()
    @base.addFeature(Feature.fromJSON(feature)) for feature in json.features
    @path = ([ Point.fromJSON(node[0]), node[1] ] for node in json.path)
    
  # Returns a JSON representation of the playfield.
  getJSON: -> {
    backgroundColor: @backgroundColor
    showGrid: @grid.visible
    gridColor: @grid.strokeStyle.style
    gridSpacing: @grid.spacing
    features: feature.toJSON() for feature in @base.getAllIntersectableFeatures()
    path: [ node[0].toJSON(), node[1] ] for node in @buildPath()
  }
  
  # Returns the progress at the specified point.
  getProgress: (point) ->
    return 0 if @path.length < 2
    closestDistance = Number.MAX_VALUE
    for index in [0...@path.length - 1]
      start = @path[index][0]
      end = @path[index + 1][0]
      closest = LineSegment.getClosestPoint(start, end, point)
      distance = closest.distance(point)
      if distance < closestDistance
        closestDistance = distance
        closestProgress = @path[index][1] + LineSegment.getProjection(start, end, point) *
          (@path[index + 1][1] - @path[index][1])
    Math.min(Math.max(closestProgress, 0), 1)  
 
  # Returns the closest path location, direction to the specified point.
  getPathLocationAndDirection: (point) ->
    return [ point, -Math.PI ] if @path.length < 2
    closestDistance = Number.MAX_VALUE
    for index in [0...@path.length - 1]
      start = @path[index][0]
      end = @path[index + 1][0]
      closest = LineSegment.getClosestPoint(start, end, point)
      distance = closest.distance(point)
      if distance < closestDistance
        closestDistance = distance
        closestPoint = Point.interpolate(start, end, LineSegment.getProjection(start, end, point))
        closestDirection = Math.atan2(end.y - start.y, end.x - start.x)
    [ closestPoint, closestDirection ]
  
  # Builds the track path by looking for marked segments.
  buildPath: ->
    startingLine = null
    finishLine = null
    pathLines = []
    endpoints = {}
    firstPath = undefined
    @base.visitAllFeatures (feature) ->
      switch feature.role
        when "starting-line"
          startingLine = feature
        when "finish-line"
          finishLine = feature
        when "path"
          pathLines.push feature
          startKey = "#{feature.start.x},#{feature.start.y}"
          points = endpoints[startKey]
          if points?
            feature.connected ?= []
            for point in points
              point.connected ?= []
              point.connected.push feature
              feature.connected.push point
          else
            points = endpoints[startKey] = []
          points.push feature
          endKey = "#{feature.end.x},#{feature.end.y}"
          points = endpoints[endKey]
          if points?
            feature.connected ?= []
            for point in points
              point.connected ?= []
              point.connected.push feature
              feature.connected.push point
          else
            points = endpoints[endKey] = []
          points.push feature
    return [] unless startingLine?
    closestDistance = Number.MAX_VALUE
    for line in pathLines
      continue if line.connected? && line.connected.length > 1
      t = startingLine.getLineIntersection(line.start, line.end)
      continue unless t?
      distance = (if t < 0 then -t else Math.max(t - 1, 0)) * line.getLength()
      if distance < closestDistance
        firstPath = line
        closestDistance = distance
    return [] unless firstPath?
    path = firstPath
    previousPath = null
    t = startingLine.getLineIntersection(firstPath.start, firstPath.end)
    totalLength = closestDistance + firstPath.getLength() * Math.min(1, if t < 0.5 then (1 - t) else t)
    path.nextPath = undefined
    while path.connected?
      previousIndex = path.connected.indexOf(previousPath)
      nextPath = path.connected[(previousIndex + 1) % path.connected.length]
      path.connected = undefined
      break if nextPath == previousPath
      path.nextPath = nextPath
      previousPath = path
      path = nextPath
      path.nextPath = undefined
      totalLength += path.getLength()
    if finishLine?
      t = finishLine.getLineIntersection(path.start, path.end)
      if t?
        totalLength -= path.getLength() * (if t < 0.5 then t else (1 - t))
    t = startingLine.getLineIntersection(firstPath.start, firstPath.end)
    accumulatedLength = firstPath.getLength() * (if t < 0.5 then -t else (t - 1))
    nodes = []
    if t < 0.5
      nodes.push [ firstPath.start, accumulatedLength / totalLength ]
      lastPoint = firstPath.end
    else
      nodes.push [ firstPath.end, accumulatedLength / totalLength ]
      lastPoint = firstPath.start
    accumulatedLength += firstPath.getLength()
    path = firstPath  
    while path.nextPath?
      path = path.nextPath
      if path.start.distance(lastPoint) < path.end.distance(lastPoint)
        nodes.push [ path.start, accumulatedLength / totalLength ]
        lastPoint = path.end
      else
        nodes.push [ path.end, accumulatedLength / totalLength ]
        lastPoint = path.start
      accumulatedLength += path.getLength()
    nodes.push [ lastPoint, accumulatedLength / totalLength ]
    nodes
    
  # Simulates the movements of the specified set of features.
  simulate: (features, speed = 1, callback) ->
    for feature in features
      feature.initSimulation()
    @stepper = setInterval((=> @step(features)), 1000 / (Playfield.FRAMES_PER_SECOND * speed))
    @lastContinuing = true
    @simulationFeatures = features
    @simulationCallback = callback
  
  # Handles a single timestep.
  step: (features) ->
    continuing = false
    for feature in features
      continuing |= feature.stepSimulation()
    unless continuing || @lastContinuing
      @stopSimulation()
    @lastContinuing = continuing # a puck that stopped might have hit another
    
  # Stops any simulation currently in progress.
  stopSimulation: ->
    return unless @stepper?
    clearInterval @stepper
    @stepper = undefined
    @simulationFeatures = undefined
    if @simulationCallback?
      @simulationCallback()
      @simulationCallback = undefined
  
  # Handles a mouse down event.
  mousedown: (event) ->
    @mouseClientX = event.clientX
    @mouseClientY = event.clientY
    return unless @gameModeEnabled && event.button == 0
    event.preventDefault()
    @mouseDown = true
    if @mouseFeature?
      @mouseFeature.mousedown()
    else
      event.target.style.cursor = "all-scroll"
      @lastPosition = new Point(event.clientX, event.clientY)
    
  # Handles a mouse up event.
  mouseup: (event) ->
    return unless @gameModeEnabled && event.button == 0
    event.preventDefault()
    event.target.style.cursor = "default"
    @clearLastPosition()
    @mouseDown = false
    @mouseFeature.mouseup() if @mouseFeature?
    @updateMouseFeature()
    
  # Handles a mouse enter event.
  mouseenter: (event) ->
    @mouseClientX = event.clientX
    @mouseClientY = event.clientY
    return unless @gameModeEnabled
    @updateMouseFeature()
    
  # Handles a mouse leave event.
  mouseleave: (event) ->
    return unless @gameModeEnabled
    event.preventDefault()
    event.target.style.cursor = "default"
    @clearLastPosition()
    @setMouseFeature undefined
    @mouseDown = false
    
  # Handles a mouse move event.
  mousemove: (event) ->
    @mouseClientX = event.clientX
    @mouseClientY = event.clientY
    unless @lastPosition?
      @updateMouseFeature() unless @mouseDown
      @mouseFeature.mousemove() if @mouseFeature?
      return
    @setTranslation(new Point(
      @base.translation.x + @lastPosition.x - event.clientX,
      @base.translation.y + @lastPosition.y - event.clientY).rounded(), 0, false)
    @lastPosition = new Point(event.clientX, event.clientY)

  # Handles a touch start event.
  touchstart: (event) ->
    return unless event.targetTouches.length == 1
    touch = event.targetTouches[0]
    @mouseClientX = touch.clientX
    @mouseClientY = touch.clientY
    return unless @gameModeEnabled
    event.preventDefault()
    @updateMouseFeature()
    @mouseDown = true
    if @mouseFeature?
      @mouseFeature.mousedown()
    else
      event.target.style.cursor = "all-scroll"
      @lastPosition = new Point(touch.clientX, touch.clientY)
  
  # Handles a touch move event.
  touchmove: (event) ->
    return unless event.targetTouches.length >= 1
    touch = event.targetTouches[0]
    @mouseClientX = touch.clientX
    @mouseClientY = touch.clientY
    unless @lastPosition?
      @mouseFeature.mousemove() if @mouseFeature?
      return
    @setTranslation(new Point(
      @base.translation.x + @lastPosition.x - touch.clientX,
      @base.translation.y + @lastPosition.y - touch.clientY).rounded(), 0, false)
    @lastPosition = new Point(touch.clientX, touch.clientY)
  
  # Handles a touch end event.
  touchend: (event) ->
    return unless event.targetTouches.length == 0 && @gameModeEnabled
    event.preventDefault()
    event.target.style.cursor = "default"
    @clearLastPosition()
    @mouseDown = false
    @mouseFeature.mouseup() if @mouseFeature?
    @setMouseFeature undefined
  
  # Clears the last position used to track panning.
  clearLastPosition: ->
    if @lastPosition?
      @translationListener(true) if @translationListener?
      @lastPosition = undefined
  
  # Updates the feature under the mouse cursor.
  updateMouseFeature: ->
    position = @base.getWorldPosition @mouseClientX, @mouseClientY
    features = @base.getFeaturesIntersectingCircle position, 1
    features.sort Feature.SORT_FUNCTION
    for feature in features.reverse()
      if feature.mousable
        @setMouseFeature(feature)
        return
    @setMouseFeature undefined

  # Sets the mouse feature.
  setMouseFeature: (feature) ->
    return if @mouseFeature == feature
    if @mouseFeature
      @mouseFeature.mouseup() if @mouseDown
      @mouseFeature.mouseleave()
    @mouseFeature = feature
    @mouseFeature.mouseenter() if @mouseFeature?

