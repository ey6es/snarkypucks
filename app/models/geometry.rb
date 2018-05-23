
# Basic 2D point class.
class Point

  # Returns an interpolated point between two other points.
  def self.interpolate(start_point, end_point, distance)
    Point.new(start_point.x + distance * (end_point.x - start_point.x),
      start_point.y + distance * (end_point.y - start_point.y))
  end
  
  # Creates a point from JSON.  
  def self.from_json(json)
    Point.new(json["x"], json["y"])
  end
  
  attr_accessor :x, :y
  
  def initialize(x = 0.0, y = 0.0)
    @x, @y = x, y
  end
  
  # Returns the length of this point as a vector.
  def length
    Math.hypot(@x, @y)
  end
  
  # Returns the JSON representation of the point.
  def to_json
    { "x" => @x, "y" => @y }
  end
  
  def to_s
    "(#{@x}, #{@y})"
  end
  
  def distance(other)
    Math.hypot(@x - other.x, @y - other.y)
  end
  
  def translated(x, y)
    Point.new(@x + x, @y + y)
  end
  
  def rotated(x, y, angle)
    vx = @x - x
    vy = @y - y
    sina = Math.sin(angle)
    cosa = Math.cos(angle)
    Point.new(x + vx * cosa - vy * sina, y + vx * sina + vy * cosa)
  end
  
  def subtracted(point)
    Point.new(@x - point.x, @y - point.y)
  end
  
  def scale(amount)
    @x *= amount
    @y *= amount
    self
  end
  
end

# Basic 2D rectangle class.
class Rectangle
  
  attr_accessor :x, :y, :width, :height
  
  def initialize(x = 0.0, y = 0.0, width = 0.0, height = 0.0)
    @x, @y, @width, @height = x, y, width, height
  end
  
  def left
    @x
  end
  
  def right
    @x + @width
  end
  
  def top
    @y
  end
  
  def bottom
    @y + @height
  end
  
  def intersects(other)
    right > other.left && left < other.right && bottom > other.top && top < other.bottom
  end
  
  def round_up!
    right = (@x + @width).ceil
    bottom = (@y + @height).ceil
    @x = @x.floor
    @y = @y.floor
    @width = right - @x
    @height = bottom - @y
    self
  end
  
  def to_s
    "(#{@x}, #{@y}, #{@width}, #{@height})"
  end
  
end

# A quadtree node.
class QuadtreeNode

  def initialize(bounds)
    @elements = []
    half_width = bounds.width / 2.0
    half_height = bounds.height / 2.0
    @child_bounds = [
      Rectangle.new(bounds.x, bounds.y, half_width, half_height),
      Rectangle.new(bounds.x + half_width, bounds.y, half_width, half_height),
      Rectangle.new(bounds.x, bounds.y + half_height, half_width, half_height),
      Rectangle.new(bounds.x + half_width, bounds.y + half_height, half_width, half_height)
    ]
    @children = [ nil, nil, nil, nil ]
  end

  # Adds an element with the described bounds to the quadtree.
  def add(element, bounds, depth)
    if depth == 0
      element.node_bounds = bounds
      @elements.push element
      return
    end
    for index in 0...@children.length
      if @child_bounds[index].intersects(bounds)
        child = @children[index]
        unless child
          child = @children[index] = QuadtreeNode.new(@child_bounds[index])
        end
        child.add(element, bounds, depth - 1)
      end
    end
  end
  
  # Removes an element with the described bounds to the quadtree.  Returns true if the node is now empty.
  def remove(element, bounds, depth)
    if depth == 0
      @elements.delete(element)
      return empty?
    end
    for index in 0...@children.length
      if @child_bounds[index].intersects(bounds)
        child = @children[index]
        if child && child.remove(element, bounds, depth - 1)
          @children[index] = nil
        end
      end
    end
    empty?
  end
  
  # Checks whether the node is empty.
  def empty?
    @elements.length == 0 && !(@children[0] || @children[1] || @children[2] || @children[3]) 
  end

  # Visits the elements intersecting the described bounds.
  def visit_intersecting(bounds, visit_number, &visitor)
    @elements.each do |element|
      if element.visit_number != visit_number
        element.visit_number = visit_number
        visitor.call(element) if element.node_bounds.intersects(bounds)
      end
    end
    for index in 0...@children.length
      child = @children[index]
      if child && @child_bounds[index].intersects(bounds)
        child.visit_intersecting(bounds, visit_number, &visitor)
      end
    end
  end

end

# A space for storing and retrieving shapes based on their bounds.
class HashSpace

  def initialize(granularity, depth)
    @granularity = granularity
    @depth = depth
    @hash = {}
    @visit_number = 0
  end
  
  # Adds an element with the described bounds to the space.
  def add(element, bounds)
    element.visit_number = 0
    depth = get_depth(bounds)
    min_x = (bounds.x / @granularity).floor
    max_x = (bounds.right / @granularity).floor
    min_y = (bounds.y / @granularity).floor
    max_y = (bounds.bottom / @granularity).floor
    for x in min_x..max_x
      for y in min_y..max_y
        key = "#{x},#{y}"
        node = @hash[key]
        unless node
          node = @hash[key] = QuadtreeNode.new(Rectangle.new(x * @granularity, y * @granularity, @granularity, @granularity))
        end
        node.add(element, bounds, depth)
      end
    end  
  end
  
  # Removes an element with the described bounds from the space.
  def remove(element, bounds)
    depth = get_depth(bounds)
    min_x = (bounds.x / @granularity).floor
    max_x = (bounds.right / @granularity).floor
    min_y = (bounds.y / @granularity).floor
    max_y = (bounds.bottom / @granularity).floor
    for x in min_x..max_x
      for y in min_y..max_y
        key = "#{x},#{y}"
        node = @hash[key]
        if node && node.remove(element, bounds, depth)
          @hash.delete(key)
        end
      end
    end  
  end
  
  # Visits the elements intersecting the given bounds.
  def visit_intersecting(bounds, &visitor)
    @visit_number += 1
    min_x = (bounds.x / @granularity).floor
    max_x = (bounds.right / @granularity).floor
    min_y = (bounds.y / @granularity).floor
    max_y = (bounds.bottom / @granularity).floor
    for x in min_x..max_x
      for y in min_y..max_y
        node = @hash["#{x},#{y}"]
        node.visit_intersecting(bounds, @visit_number, &visitor) if node
      end
    end  
  end
  
  private
  
    def get_depth(bounds)
      [ 0, -Math.log2([ bounds.width, bounds.height ].max / @granularity).round, @depth ].sort![1]
    end
end
