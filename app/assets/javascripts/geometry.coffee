# Basic geometry functionality

root = exports ? this

# A 2D point
class root.Point
  # Returns an interpolated point between two other points.
  @interpolate: (start, end, distance) ->
    new Point(start.x + distance * (end.x - start.x), start.y + distance * (end.y - start.y))

  # Creates a point from its JSON representation.
  @fromJSON: (json) ->
    new Point(json.x, json.y)

  constructor: (@x = 0.0, @y = 0.0) ->

  # Returns the length of this point as a vector.
  length: ->
    Math.sqrt(@x*@x + @y*@y)

  # Checks this point for equality with another.
  equals: (other) ->
    other? && @x == other.x && @y == other.y
  
  # Returns the JSON representation of this point.
  toJSON: ->
    { x: @x, y: @y }
  
  # Returns a string representation of this point.
  toString: ->
    "(#{@x}, #{@y})"
  
  # Returns the length of this point as a vector.
  length: ->
    Math.sqrt(@x*@x + @y*@y)
  
  # Returns the distance from this point to another.
  distance: (other) ->
    dx = @x - other.x
    dy = @y - other.y
    Math.sqrt(dx*dx + dy*dy)

  # Returns a translation of this point by the specified amount.
  translated: (x, y) ->
    new Point(@x + x, @y + y)
  
  # Returns a rotation of this point by the specified angle about the given center.
  rotated: (x, y, angle) ->
    vx = @x - x
    vy = @y - y
    sina = Math.sin(angle)
    cosa = Math.cos(angle)
    new Point(x + vx * cosa - vy * sina, y + vx * sina + vy * cosa)
  
  # Returns a scaled version of this point by the specified amount about the given center.  
  scaled: (x, y, amount) ->
    new Point(x + (@x - x) * amount, y + (@y - y) * amount)

  # Returns a rounded version of this point.
  rounded: ->
    new Point(Math.round(@x), Math.round(@y))

  # Returns a new point with the value of the given point subtracted from this.
  subtracted: (point) ->
    new Point(@x - point.x, @y - point.y)

  # Adds the specified point to this and returns this.
  plus: (point) ->
    @x += point.x
    @y += point.y
    this

  # Subtracts the specified point from this and returns this.
  minus: (point) ->
    @x -= point.x
    @y -= point.y
    this

  # Normalizes this point as a vector and returns this.
  normalize: ->
    @scale(1 / @length())

  # Multiplies this point by a scalar and returns this.
  scale: (amount) ->
    @x *= amount
    @y *= amount
    this


# A 2D rectangle
class root.Rectangle
  constructor: (@x = 0.0, @y = 0.0, @width = 0.0, @height = 0.0) ->

  # Returns the left edge of the rectangle.
  left: -> @x

  # Returns the right edge of the rectangle.
  right: -> @x + @width
  
  # Returns the top edge of the rectangle.
  top: -> @y 

  # Returns the bottom edge of the rectangle.
  bottom: -> @y + @height
  
  # Returns the length of the rectangle's diagonal.
  diagonalLength: ->
    Math.sqrt(@width*@width + @height*@height)
  
  # Checks this rectangle for equality with another.
  equals: (other) ->
    other? && @x == other.x && @y == other.y && @width == other.width && @height == other.height
  
  # Checks whether this rectangle is empty.
  isEmpty: ->
    @width <= 0 || @height <= 0
  
  # Rounds this rectangle up to the nearest integer coordinates and returns this.
  roundUp: ->
    right = Math.ceil(@x + @width)
    bottom = Math.ceil(@y + @height)
    @x = Math.floor(@x)
    @y = Math.floor(@y)
    @width = right - @x
    @height = bottom - @y
    this
  
  # Returns the translation of this rectangle by the specified amount.
  translated: (tx, ty) ->
    new Rectangle(@x + tx, @y + ty, @width, @height)
    
  # Checks whether this rectangle intersects another.
  intersects: (other) ->
    @right() > other.left() && @left() < other.right() &&
    @bottom() > other.top() && @top() < other.bottom()
  
  # Checks whether this rectangle contains another.
  contains: (other) ->
    @left() <= other.left() && @right() >= other.right() &&
    @top() <= other.top() && @bottom() >= other.bottom()
  
  # Returns the union of this rectangle and the supplied other.
  union: (other) ->
    x = Math.min(@x, other.x)
    y = Math.min(@y, other.y)
    new Rectangle(x, y, Math.max(@right(), other.right()) - x, Math.max(@bottom(), other.bottom()) - y)

  # Returns the intersection of this rectangle and the supplied other.
  intersection: (other) ->
    x = Math.max(@x, other.x)
    y = Math.max(@y, other.y)
    new Rectangle(x, y, Math.min(@right(), other.right()) - x, Math.min(@bottom(), other.bottom()) - y)


# A quadtree node.
class QuadtreeNode
  constructor: (bounds) ->
    @elements = []
    halfWidth = bounds.width / 2
    halfHeight = bounds.height / 2
    @childBounds = [
      new Rectangle(bounds.x, bounds.y, halfWidth, halfHeight)
      new Rectangle(bounds.x + halfWidth, bounds.y, halfWidth, halfHeight)
      new Rectangle(bounds.x, bounds.y + halfHeight, halfWidth, halfHeight)
      new Rectangle(bounds.x + halfWidth, bounds.y + halfHeight, halfWidth, halfHeight)
    ]
    @children = [ null, null, null, null ]
  
  # Adds an element with the described bounds to the quadtree.
  add: (element, bounds, depth) ->
    if depth == 0
      element.nodeBounds = bounds
      @elements.push(element)
      return
    for index in [0...@children.length]
      if @childBounds[index].intersects(bounds)
        child = @children[index]
        unless child?
          child = @children[index] = new QuadtreeNode(@childBounds[index])
        child.add(element, bounds, depth - 1)
    
  # Removes an element with the described bounds to the quadtree.  Returns true if the node is now empty.
  remove: (element, bounds, depth) ->
    if depth == 0
      index = @elements.indexOf(element)
      @elements.splice(index, 1) unless index == -1
      return @isEmpty()
    for index in [0...@children.length]
      if @childBounds[index].intersects(bounds)
        child = @children[index]
        if child? && child.remove(element, bounds, depth - 1)
          @children[index] = null
    @isEmpty()
  
  # Checks whether this node is empty (has no elements or children).
  isEmpty: ->
    @elements.length == 0 && !(@children[0]? || @children[1]? || @children[2]? || @children[3]?) 
  
  # Visits the elements intersecting the described bounds.
  visitIntersecting: (bounds, visitor, visitNumber) ->
    for element in @elements
      if element.visitNumber != visitNumber
        element.visitNumber = visitNumber
        visitor(element) if element.nodeBounds.intersects(bounds)
    for index in [0...@children.length]
      child = @children[index]
      if child? && @childBounds[index].intersects(bounds)
        child.visitIntersecting(bounds, visitor, visitNumber)

  # Visits all elements in the node.
  visitAll: (visitor, visitNumber) ->
    for element in @elements
      if element.visitNumber != visitNumber
        element.visitNumber = visitNumber
        visitor(element)
    for child in @children
      child.visitAll(visitor, visitNumber) if child?


# A space for storing and retrieving shapes based on their bounds.
class root.HashSpace
  constructor: (@granularity, @depth) ->
    @hash = {}
    @visitNumber = 0
  
  # Adds an element with the described bounds to the space.
  add: (element, bounds) ->
    element.visitNumber = 0
    depth = @getDepth(bounds)
    for x in [(bounds.x // @granularity)..(bounds.right() // @granularity)]
      for y in [(bounds.y // @granularity)..(bounds.bottom() // @granularity)]
        key = "#{x},#{y}"
        node = @hash[key]
        unless node?
          node = @hash[key] = new QuadtreeNode(new Rectangle(x * @granularity, y * @granularity, @granularity, @granularity))
        node.add(element, bounds, depth)
  
  # Removes an element with the described bounds from the space.
  remove: (element, bounds) ->
    depth = @getDepth(bounds)
    for x in [(bounds.x // @granularity)..(bounds.right() // @granularity)]
      for y in [(bounds.y // @granularity)..(bounds.bottom() // @granularity)]
        key = "#{x},#{y}"
        node = @hash[key]
        if node? && node.remove(element, bounds, depth)
          delete @hash[key]
  
  # Removes everything from the space.
  clear: ->
    @hash = {}
  
  # Returns the natural quadtree depth of the specified bounds.
  getDepth: (bounds) ->
    Math.min(Math.max(Math.round(-Math.log(Math.max(bounds.width, bounds.height) / @granularity) / Math.log(2)), 0), @depth)
        
  # Visits all elements intersecting the described bounds. 
  visitIntersecting: (bounds, visitor) ->
    @visitNumber++
    for x in [(bounds.x // @granularity)..(bounds.right() // @granularity)]
      for y in [(bounds.y // @granularity)..(bounds.bottom() // @granularity)]
        node = @hash["#{x},#{y}"]
        node.visitIntersecting(bounds, visitor, @visitNumber) if node?

  # Visits all elements. 
  visitAll: (visitor) ->
    @visitNumber++
    for own key, node of @hash
      node.visitAll(visitor, @visitNumber)
    

