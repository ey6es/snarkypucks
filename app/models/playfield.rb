require_dependency "geometry"

# Base class for all playfield features.
class Feature
  
  # Creates a feature from JSON.  
  def self.from_json(json)
    feature = const_get(json["type"]).new
    feature.from_json(json)
    feature
  end
  
  attr_accessor :collidable, :reflectivity, :visit_number, :node_bounds
  attr_reader :bounds, :playfield
  
  def initialize
    @collidable = true
    @reflectivity = 1.0
    update_bounds
  end
  
  def intersects_circle(center, radius)
    false
  end
  
  def path_segment_collision(feature, start_point, end_point)
    nil
  end
  
  def penetration_vector(puck)
    nil
  end
  
  # Returns the JSON representation of the feature.
  def to_json(json = nil)
    json ||= { type: "Feature" }
    json["collidable"] = @collidable
    json["reflectivity"] = @reflectivity
    json
  end
  
  # Loads the feature's properties from its JSON representation.
  def from_json(json)
    @collidable = json["collidable"]
    @reflectivity = json["reflectivity"]
  end
  
  def playfield=(playfield)
    @playfield = playfield
  end
  
  protected
  
    def update_bounds
    end
    
    def bounds=(bounds)
      playfield = @playfield
      playfield.remove_feature(self) if playfield
      @bounds = bounds
      playfield.add_feature(self) if playfield
    end
end

# An image feature.
class ImageFeature < Feature
  
  attr_accessor :prompt
  attr_reader :translation, :rotation, :url, :role

  def initialize(translation = Point.new, rotation = 0.0, url = "")
    @translation, @rotation, @url = translation, rotation, url
    @width, @height = 0.0, 0.0
    @role = "none"
    super()
  end
  
  def initialize_dup(other)
    super(other)
    @playfield = nil
    @role = "none"
  end
  
  def set_position(translation, rotation = 0.0)
    @translation, @rotation = translation, rotation
    update_bounds
  end
  
  def role=(role)
    if @playfield && @role.end_with?("-prompt")
      @playfield.prompt_images.delete(self)
    end
    @role = role
    if @playfield && @role.end_with?("-prompt")
      @playfield.prompt_images.push(self)
    end
  end
  
  def intersects_circle(center, radius)
    Polygon.get_closest_point(@vertices, center).distance(center) < radius
  end
  
  def path_segment_collision(feature, start_point, end_point)
    if @prompt && Polygon.path_segment_collision(@vertices, feature.expanded_radius, start_point, end_point, 1.0)
      @playfield.collided_prompts.push @prompt
      @playfield.remove_feature self
      return nil
    end
    return nil unless @collidable
    if @role != "boost" && @role != "omniboost"
      return Polygon.path_segment_collision(@vertices, feature.expanded_radius,
        start_point, end_point, @reflectivity)
    end
    return nil if feature.last_collision_feature == self
    closest = LineSegment.get_closest_point(start_point, end_point, @translation)
    if closest.distance(@translation) >= feature.expanded_radius
      return nil
    end
    t = LineSegment.get_projection(start_point, end_point, closest)
    vector = Point.new(end_point.x - closest.x, end_point.y - closest.y)
    length = vector.length()
    return nil if length == 0.0
    if @role == "boost"
      vector = Point.new(0.0, -length).rotated(0.0, 0.0, @rotation)
    end
    vector.scale(@reflectivity)
    [ t, closest.translated(vector.x, vector.y) ]
  end
  
  def penetration_vector(puck)
    return nil unless @collidable && @role != "boost" && @role != "omniboost"
    Polygon.penetration_vector(@vertices, puck.center, puck.expanded_radius)
  end
  
  def to_json(json = nil)
    json ||= { type: "ImageFeature" }
    json["translation"] = @translation.to_json
    json["rotation"] = @rotation
    json["url"] = @url
    json["role"] = @role
    json["width"] = @width
    json["height"] = @height
    json["prompt"] = @prompt
    super json
  end
  
  def from_json(json)
    super json
    @url = json["url"]
    self.role = json["role"]
    @width = json["width"]
    @height = json["height"]
    self.set_position Point.from_json(json["translation"]), json["rotation"]
    @prompt = json["prompt"]
  end
  
  def playfield=(playfield)
    if @playfield && @role.end_with?("-prompt")
      @playfield.prompt_images.delete(self)
    end
    @playfield = playfield
    if @playfield && @role.end_with?("-prompt")
      @playfield.prompt_images.push(self)
    end
  end
  
  protected
  
    def update_bounds
      left = @translation.x - @width / 2.0
      top = @translation.y - @height / 2.0
      right = @translation.x + @width / 2.0
      bottom = @translation.y + @height / 2.0
      @vertices = [
        Point.new(left, top).rotated(@translation.x, @translation.y, @rotation),
        Point.new(right, top).rotated(@translation.x, @translation.y, @rotation),
        Point.new(right, bottom).rotated(@translation.x, @translation.y, @rotation),
        Point.new(left, bottom).rotated(@translation.x, @translation.y, @rotation) ]
      self.bounds = Polygon.bounds(@vertices, 1.0).round_up!
    end
end

# Base class of stroked features.
class StrokedFeature < Feature

  attr_reader :line_width, :stroke_style

  def initialize
    @line_width = Puck::LINE_WIDTH
    @stroke_style = "#000000"
    super()
  end
  
  def line_width=(width)
    @line_width = width
    update_bounds
  end
  
  def to_json(json = nil)
    json ||= { type: "StrokedFeature" }
    json["lineWidth"] = @line_width
    super json
  end
  
  def from_json(json)
    super json
    self.line_width = json["lineWidth"]
    @stroke_style = json["strokeStyle"] if json.has_key?("strokeStyle")
  end
  
  def stroke_radius
    @stroke_style ? @line_width / 2.0 : 0.0
  end
  
end

# A line segment feature.
class LineSegment < StrokedFeature

  # Returns the closest point on the described segment to the point given.
  def self.get_closest_point(start_point, end_point, point)
    length = start_point.distance(end_point)
    return start_point if length == 0.0
    unit_x = (end_point.x - start_point.x) / length
    unit_y = (end_point.y - start_point.y) / length
    product = (point.x - start_point.x) * unit_x + (point.y - start_point.y) * unit_y
    if product < 0.0
      start_point
    elsif product > length
      end_point
    else
      Point.new(start_point.x + product * unit_x, start_point.y + product * unit_y)
    end
  end
  
  # Returns the projection of the specified point onto the described segment.
  def self.get_projection(start_point, end_point, point)
    dx = end_point.x - start_point.x
    dy = end_point.y - start_point.y
    l2 = dx*dx + dy*dy
    return 0.0 if l2 == 0.0
    ((point.x - start_point.x) * dx + (point.y - start_point.y) * dy) / l2
  end
  
  # Checks for a collision between the described segment and path segment.
  def self.path_segment_collision(start_point, end_point, radius, path_start, path_end, reflectivity)
    length = start_point.distance(end_point)
    if length == 0.0
      return Circle.path_segment_collision(start_point, radius, path_start, path_end, reflectivity)
    end
    tx = (end_point.x - start_point.x) / length
    ty = (end_point.y - start_point.y) / length # line tangent
    nx = -ty
    ny = tx # line normal
    ox = path_start.x - start_point.x
    oy = path_start.y - start_point.y
    dividend = ox*nx + oy*ny
    if dividend > -radius && dividend < radius
      projection = ox*tx + oy*ty
      if projection < 0.0
        return Circle.path_segment_collision(start_point, radius, path_start, path_end, reflectivity)
      end
      if projection > length
        return Circle.path_segment_collision(end_point, radius, path_start, path_end, reflectivity)
      end
    end
    dx = path_end.x - path_start.x
    dy = path_end.y - path_start.y
    divisor = dx*nx + dy*ny
    if dividend < 0.0
      return nil if divisor <= 0.0  
      dividend = -radius - dividend
    else
      return nil if divisor >= 0.0
      dividend = radius - dividend
    end
    t = dividend / divisor
    return nil if (t < 0.0 || t > 1.0)
    cx = ox + t*dx
    cy = oy + t*dy
    projection = cx*tx + cy*ty
    if projection < 0.0
      return Circle.path_segment_collision(start_point, radius, path_start, path_end, reflectivity)
    end
    if projection > length
      return Circle.path_segment_collision(end_point, radius, path_start, path_end, reflectivity)
    end
    remaining = 1.0 - t
    px = dx * remaining
    py = dy * remaining # penetration vector
    dot_product = tx*px + ty*py
    rx = 2.0*dot_product*tx - px
    ry = 2.0*dot_product*ty - py # reflection vector
    [ t, Point.new(path_start.x + t*dx + rx*reflectivity, path_start.y + t*dy + ry*reflectivity) ] 
  end
  
  # Find the penetration vector for the specified segment and circle.
  def self.penetration_vector(start_point, end_point, center, radius)
    Circle.penetration_vector(LineSegment.get_closest_point(start_point, end_point, center), center, radius)
  end
  
  attr_reader :start_point, :end_point, :role

  def initialize(start_point = Point.new, end_point = Point.new)
    @start_point, @end_point = start_point, end_point
    @role = "none"
    super()
  end

  def set_endpoints(start_point, end_point)
    @start_point, @end_point = start_point, end_point
    update_bounds
  end

  def role=(role)
    if @playfield && @role == "starting-line"
      @playfield.starting_lines.delete(self)
    end
    @role = role
    if @playfield && @role == "starting-line"
      @playfield.starting_lines.push(self)
    end
    @collidable = false unless @role == "none" || @role == "finish-line"
  end

  def length
    @start_point.distance(@end_point)
  end

  def intersects_circle(center, radius)
    LineSegment.get_closest_point(@start_point, @end_point, center).distance(center) < radius + @line_width / 2.0
  end
  
  def path_segment_collision(feature, start_point, end_point)
    return nil unless @collidable
    LineSegment.path_segment_collision(@start_point, @end_point, @line_width / 2.0 + feature.expanded_radius,
      start_point, end_point, @reflectivity)
  end
  
  def penetration_vector(puck)
    return nil unless @collidable
    LineSegment.penetration_vector(@start_point, @end_point, puck.center, @line_width / 2.0 + puck.expanded_radius)
  end
  
  def to_json(json = nil)
    json ||= { type: "LineSegment" }
    json["start"] = @start_point.to_json
    json["end"] = @end_point.to_json
    json["role"] = @role
    super json
  end
  
  def from_json(json)
    super json
    self.set_endpoints Point.from_json(json["start"]), Point.from_json(json["end"])
    self.role = json["role"]
  end
  
  def playfield=(playfield)
    if @playfield && @role == "starting-line"
      @playfield.starting_lines.delete(self)
    end
    @playfield = playfield
    if @playfield && @role == "starting-line"
      @playfield.starting_lines.push(self)
    end
  end
  
  protected
  
    def update_bounds
      expansion = (@line_width / 2.0).ceil + 1
      min_x = [ @start_point.x, @end_point.x ].min - expansion
      min_y = [ @start_point.y, @end_point.y ].min - expansion
      self.bounds = Rectangle.new(min_x, min_y, [ @start_point.x, @end_point.x ].max - min_x + expansion,
        [ @start_point.y, @end_point.y ].max - min_y + expansion).round_up!
    end
end

# An arc feature.
class Arc < StrokedFeature
  
  def self.segment_intersection(start_point, end_point, center, radius,
      start_angle = -Math::PI, end_angle = Math::PI, orientation = 0.0)
    ox = start_point.x - center.x
    oy = start_point.y - center.y
    dx = end_point.x - start_point.x
    dy = end_point.y - start_point.y
    a = dx*dx + dy*dy 
    return nil if a == 0.0
    b = 2.0 * (dx*ox + dy*oy)
    c = ox*ox + oy*oy - radius*radius
    radicand = b*b - 4*a*c
    return nil if radicand < 0.0
    radical = Math.sqrt(radicand)
    first = (-b - radical) / (2*a)
    second = (-b + radical) / (2*a)
    fx = ox + first * dx
    fy = oy + first * dy
    first = nil unless first >= 0.0 && first <= 1.0 && (fx*dx + fy*dy)*orientation <= 0.0 &&
      contains_angle?(start_angle, end_angle, Math.atan2(fy, fx))
    sx = ox + second * dx
    sy = oy + second * dy
    second = nil unless second >= 0.0 && second <= 1.0 && (sx*dx + sy*dy)*orientation <= 0.0 &&
      contains_angle?(start_angle, end_angle, Math.atan2(sy, sx))
    return second unless first
    return first unless second
    [ first, second ].min
  end
  
  def self.contains_angle?(start_angle, end_angle, angle)
    if end_angle > start_angle
      return angle >= start_angle && angle <= end_angle
    end
    angle >= start_angle || angle <= end_angle
  end
  
  attr_reader :center, :radius, :start_angle, :end_angle
  
  def initialize(center = Point.new, radius = 0.0, start_angle = -Math::PI, end_angle = Math::PI)
    @center, @radius, @start_angle, @end_angle = center, radius, start_angle, end_angle
    super()
    update_points
  end
  
  def set_parameters(center, radius, start_angle = -Math::PI, end_angle = Math::PI)
    @center, @radius, @start_angle, @end_angle = center, radius, start_angle, end_angle
    update_points
    update_bounds
  end
  
  def intersects_circle(center, radius)
    distance = @center.distance(center)
    expansion = radius + @line_width / 2.0
    return distance < @radius + expansion if @radius == 0
    return false if distance > @radius + expansion
    return false if distance < @radius - expansion
    angle = Math.atan2(center.y - @center.y, center.x - @center.x)
    Arc.contains_angle?(@start_angle, @end_angle, angle) || @start_point.distance(center) <= expansion ||
      @end_point.distance(center) <= expansion
  end
  
  def path_segment_collision(feature, start_point, end_point)
    return nil unless @collidable
    expansion = @line_width / 2.0 + feature.expanded_radius
    t0 = Arc.segment_intersection(start_point, end_point, @center, @radius + expansion, @start_angle, @end_angle, 1.0)
    t1 = Arc.segment_intersection(start_point, end_point, @center, @radius - expansion, @start_angle, @end_angle, -1.0)
    t2 = Arc.segment_intersection(start_point, end_point, @start_point, expansion, -Math::PI, Math::PI, 1.0)
    t3 = Arc.segment_intersection(start_point, end_point, @end_point, expansion, -Math::PI, Math::PI, 1.0)
    if t0 && !(t1 && t0 > t1 || t2 && t0 > t2 || t3 && t0 > t3)
      t = t0
      center = @center
    elsif t1 && !(t2 && t1 > t2 || t3 && t1 > t3)
      t = t1
      center = @center
    elsif t2 && !(t3 && t2 > t3)
      t = t2
      center = @start_point
    elsif t3
      t = t3
      center = @end_point
    else
      return nil
    end
    dx = end_point.x - start_point.x
    dy = end_point.y - start_point.y
    tx = start_point.x - center.x + t*dx
    ty = start_point.y - center.y + t*dy # compute the collision tangent
    length = Math.sqrt(tx*tx + ty*ty)
    if length > 0.0
      tmp = tx
      tx = -ty / length 
      ty = tmp / length
    else
      tx = 1.0
      ty = 0.0
    end
    remaining = 1.0 - t
    px = dx * remaining
    py = dy * remaining # penetration vector
    dot_product = tx*px + ty*py
    rx = 2.0*dot_product*tx - px
    ry = 2.0*dot_product*ty - py # reflection vector
    [ t, Point.new(start_point.x + t*dx + rx*@reflectivity, start_point.y + t*dy + ry*@reflectivity) ]
  end
  
  def penetration_vector(puck)
    return nil unless @collidable
    angle = Math.atan2(puck.center.y - @center.y, puck.center.x - @center.x)
    if @end_angle >= @start_angle
      angle = [ @start_angle, angle, @end_angle ].sort[1]
    else
      midpoint = @end_angle + (@start_angle - @end_angle) / 2.0
      if angle >= midpoint
        angle = [ angle, @start_angle ].max
      else
        angle = [ angle, @end_angle ].min
      end
    end
    zero = Point.new(@center.x + @radius, @center.y)
    closest = zero.rotated(@center.x, @center.y, angle)
    Circle.penetration_vector(closest, puck.center, @line_width / 2.0 + puck.expanded_radius)
  end
  
  def to_json(json = nil)
    json ||= { type: "Arc" }
    json["center"] = @center.to_json
    json["radius"] = @radius
    json["startAngle"] = @start_angle
    json["endAngle"] = @end_angle
    super json
  end
  
  def from_json(json)
    super json
    set_parameters Point.from_json(json["center"]), json["radius"], json["startAngle"], json["endAngle"]
  end
  
  protected
  
    def update_bounds
      expanded_radius = @radius + (@line_width / 2.0).ceil + 1
      self.bounds = Rectangle.new(@center.x - expanded_radius, @center.y - expanded_radius,
        expanded_radius * 2, expanded_radius * 2).round_up!
    end
    
    def update_points
      @start_point = Point.new(@center.x + @radius * Math.cos(@start_angle), @center.y + @radius * Math.sin(@start_angle))
      @end_point = Point.new(@center.x + @radius * Math.cos(@end_angle), @center.y + @radius * Math.sin(@end_angle))
    end
end

# A circle feature.
class Circle < StrokedFeature

  # Checks for a collision between the described circle and path segment.
  def self.path_segment_collision(center, radius, start_point, end_point, reflectivity)
    ox = start_point.x - center.x
    oy = start_point.y - center.y
    dx = end_point.x - start_point.x
    dy = end_point.y - start_point.y
    a = dx*dx + dy*dy 
    return nil if a == 0.0
    b = 2.0 * (dx*ox + dy*oy)
    return nil if b >= 0.0 # make sure we're heading towards the circle
    c = ox*ox + oy*oy - radius*radius
    radicand = b*b - 4.0*a*c
    return nil if radicand < 0.0
    radical = Math.sqrt(radicand)
    t = (-b - radical) / (2.0*a)
    return nil if (t < 0.0 || t > 1.0)
    tx = ox + t*dx
    ty = oy + t*dy # compute the collision tangent
    length = Math.sqrt(tx*tx + ty*ty)
    if length > 0.0
      tmp = tx
      tx = -ty / length 
      ty = tmp / length
    else
      tx = 1.0
      ty = 0.0
    end
    remaining = 1.0 - t
    px = dx * remaining
    py = dy * remaining # penetration vector
    dot_product = tx*px + ty*py
    rx = 2.0*dot_product*tx - px
    ry = 2.0*dot_product*ty - py # reflection vector
    [ t, Point.new(start_point.x + t*dx + rx*reflectivity, start_point.y + t*dy + ry*reflectivity) ] 
  end
  
  # Returns the penetration vector for the described circles.
  def self.penetration_vector(point, center, combined_radius)
    dx = center.x - point.x
    dy = center.y - point.y
    length = Math.sqrt(dx*dx + dy*dy)
    if length == 0.0
      dx = 1.0
      dy = 0.0
    else
      dx /= length
      dy /= length
    end
    scale = combined_radius - length
    Point.new(dx * scale, dy * scale)
  end
  
  attr_reader :center, :radius

  def initialize(center = Point.new, radius = 0.0)
    @center, @radius = center, radius
    super()
  end

  def set_parameters(center, radius)
    @center, @radius = center, radius
    update_bounds
  end

  def expanded_radius
    @radius + stroke_radius
  end
  
  def intersects_circle(center, radius)
    @center.distance(center) < radius + expanded_radius
  end
  
  def path_segment_collision(feature, start_point, end_point)
    return nil unless @collidable
    Circle.path_segment_collision(@center, expanded_radius + feature.expanded_radius,
      start_point, end_point, @reflectivity)
  end
  
  def penetration_vector(puck)
    return nil unless @collidable
    Circle.penetration_vector(@center, puck.center, expanded_radius + puck.expanded_radius)
  end
  
  def to_json(json = nil)
    json ||= { type: "Circle" }
    json["center"] = @center.to_json
    json["radius"] = @radius
    super json
  end
  
  def from_json(json)
    super json
    set_parameters Point.from_json(json["center"]), json["radius"]
  end
  
  protected
  
    def update_bounds
      expanded_radius = @radius + (@line_width / 2.0).ceil + 1
      self.bounds = Rectangle.new(@center.x - expanded_radius, @center.y - expanded_radius,
        expanded_radius * 2, expanded_radius * 2).round_up!
    end
end

# A polygon feature.
class Polygon < StrokedFeature

  # Computes the bounds of the described polygon.
  def self.bounds(vertices, expansion = 0.0)
    min_x = min_y = Float::MAX
    max_x = max_y = -Float::MAX
    vertices.each do |vertex|
      min_x = [ min_x, vertex.x ].min
      min_y = [ min_y, vertex.y ].min
      max_x = [ max_x, vertex.x ].max
      max_y = [ max_y, vertex.y ].max
    end
    Rectangle.new(min_x - expansion, min_y - expansion, max_x - min_x + expansion * 2.0, max_y - min_y + expansion * 2.0)
  end

  # Returns the closest point on the described polygon to the point given.
  def self.get_closest_point(vertices, point)
    orientation = Polygon.orientation(vertices)
    outside_last_last = outside_edge?(vertices, orientation, point, vertices.length - 2)
    outside_last = outside_edge?(vertices, orientation, point, vertices.length - 1)
    for index in 0...vertices.length
      outside = outside_edge?(vertices, orientation, point, index)
      if outside_last
        return vertices[index] if outside
        unless outside_last_last
          return LineSegment.get_closest_point(vertices[(index + vertices.length - 1) % vertices.length],
            vertices[index], point)
        end
      end
      outside_last_last = outside_last
      outside_last = outside
    end
    point
  end

  # Checks for a collision between the described polygon and path segment.
  def self.path_segment_collision(vertices, radius, start_point, end_point, reflectivity)
    orientation = Polygon.orientation(vertices)
    outside_last_last = outside_edge?(vertices, orientation, start_point, vertices.length - 2)
    outside_last = outside_edge?(vertices, orientation, start_point, vertices.length - 1)
    for index in 0...vertices.length
      outside = outside_edge?(vertices, orientation, start_point, index)
      if outside_last
        if outside
          first_collision = LineSegment.path_segment_collision(vertices[(index + vertices.length - 1) % vertices.length],
            vertices[index], radius, start_point, end_point, reflectivity)
          second_collision = LineSegment.path_segment_collision(vertices[index], vertices[(index + 1) % vertices.length],
            radius, start_point, end_point, reflectivity)
          return first_collision unless second_collision
          return second_collision unless first_collision
          return first_collision[0] < second_collision[0] ? first_collision : second_collision
        end
        unless outside_last_last
          return LineSegment.path_segment_collision(vertices[(index + vertices.length - 1) % vertices.length],
            vertices[index], radius, start_point, end_point, reflectivity)
        end 
      end
      outside_last_last = outside_last
      outside_last = outside
    end
    nil
  end
  
  # Find the penetration vector for the specified polygon and circle.
  def self.penetration_vector(vertices, center, radius)
    Circle.penetration_vector(Polygon.get_closest_point(vertices, center), center, radius)
  end
  
  # Returns the orientation of the described polygon (+1 for CW, -1 for CCW)
  def self.orientation(vertices)
    for index in 0...vertices.length
      a = vertices[index]
      b = vertices[(index + 1) % vertices.length]
      c = vertices[(index + 2) % vertices.length]
      cross_product = (b.x - a.x) * (c.y - b.y) - (c.x - b.x) * (b.y - a.y)
      return 1.0 if cross_product > 0.0
      return -1.0 if cross_product < 0.0
    end
    1.0
  end
  
  # Checks whether the specified point is outside the indexed edge.
  def self.outside_edge?(vertices, orientation, point, index)
    start_point = vertices[index]
    end_point = vertices[(index + 1) % vertices.length]
    cross_product = (point.x - start_point.x) * (end_point.y - start_point.y) -
      (end_point.x - start_point.x) * (point.y - start_point.y)
    orientation * cross_product > 0.0
  end
  
  attr_reader :vertices
  
  def initialize(vertices = [ Point.new, Point.new, Point.new ])
    @vertices = vertices
    super()
  end

  def vertices=(vertices)
    @vertices = vertices
    update_bounds
  end

  def intersects_circle(center, radius)
    Polygon.get_closest_point(@vertices, center).distance(center) < radius + stroke_radius
  end
  
  def path_segment_collision(feature, start_point, end_point)
    return nil unless @collidable
    Polygon.path_segment_collision(@vertices, stroke_radius + feature.expanded_radius,
      start_point, end_point, @reflectivity)
  end
  
  def penetration_vector(puck)
    return nil unless @collidable
    nil
  end
  
  def to_json(json = nil)
    json ||= { type: "Polygon" }
    json["vertices"] = @vertices.collect { |vertex| vertex.to_json }
    super json
  end
  
  def from_json(json)
    super json
    self.vertices = json["vertices"].collect { |json| Point.from_json(json) }
  end
  
  protected
  
    def update_bounds
      expansion = (@line_width / 2.0).ceil + 1
      self.bounds = Polygon.bounds(@vertices, expansion).round_up!
    end
end

# A text string feature.
class TextFeature < StrokedFeature
end

# A puck feature.
class Puck < Circle

  # The radius of the pucks.
  RADIUS = 20.0

  # The minimum amount of padding between pucks when starting.
  PADDING = 7.5

  # Semi-sane limit on number of iterations when depenetrating.
  MAX_DEPENETRATION_ITERATIONS = 10
  
  # The acceleration due to friction.
  FRICTION_ACCELERATION = -0.375
  
  # A small threshold value.
  EPSILON = 0.01
  
  # The puck line width.
  LINE_WIDTH = 3
  
  # The available puck colors.
  COLORS = [ "red", "orange", "yellow", "green", "blue", "indigo", "violet", "cyan",
    "magenta", "brown", "chartreuse", "silver", "tan", "coral", "gray", "royalblue" ]

  attr_reader :translation
  attr_accessor :color, :player_id, :queue, :finish_order, :progress,
    :move_distances, :pause_steps_remaining, :last_collision_feature, :debug
 
  def initialize(translation = Point.new, color = COLORS[0], player_id = 0)
    super translation, RADIUS
    @translation = translation
    @color = color
    @player_id = player_id
    @queue = []
    @move_distances = []
    @debug = false
  end
  
  def set_position(translation)
    @translation = translation
    set_parameters translation, RADIUS
  end
  
  def init_simulation
    @last_collision_feature = nil
    @step_count = 0
    start_next_move
  end
  
  def step_simulation
    @step_count += 1
    return false if @finish_order
    return false unless @move_start || (@performing_action && @performing_action.pause) || start_next_move
    if @performing_action
      if @performing_action.pause
        unless @performing_action.step(self)
          @performing_action = nil
          return start_next_move
        end
        return true
      else
        @performing_action.step(self)
      end
    end
    @elapsed_time += 1
    if @elapsed_time < move_time
      total_distance = @move_start.distance(@move_end)
      distance = @elapsed_time * @elapsed_time * FRICTION_ACCELERATION / 2.0 + @elapsed_time *
        Math.sqrt(-2.0 * total_distance * FRICTION_ACCELERATION)
      step_to Point.interpolate(@move_start, @move_end, distance / total_distance) 
    else
      step_to @move_end
    end
    depenetrate
    return false if @finish_order
    unless @move_start && @elapsed_time < move_time
      return start_next_move
    end
    true
  end
  
  def depenetrate
    for iteration in 0...MAX_DEPENETRATION_ITERATIONS
      penetration = get_longest_penetration
      if penetration
        if @debug
          puts "#{@player_id} #{@step_count} resolving penetration #{penetration.x} #{penetration.y}"
        end
        translate penetration.x, penetration.y
      else
        break
      end
    end
  end
  
  def translate(x, y)
    set_position @translation.translated(x, y)
    if @move_start
      @move_start = @move_start.translated(x, y)
      @move_end = @move_end.translated(x, y)
    end
  end
  
  def velocity
    return Point.new() unless @move_start
    total_distance = @move_start.distance(@move_end)
    speed = [ 0.0, Math.sqrt(-2.0 * total_distance * FRICTION_ACCELERATION) +
      @elapsed_time * FRICTION_ACCELERATION ].max
    return Point.new() if speed == 0.0
    scale = speed / total_distance
    Point.new((@move_end.x - @move_start.x) * scale, (@move_end.y - @move_start.y) * scale)
  end
  
  def velocity=(new_velocity)
    length = new_velocity.length
    if length < EPSILON
      @move_start = nil
      return
    end
    @move_start = @translation
    scale = length / (-2.0 * FRICTION_ACCELERATION)
    @move_end = Point.new(@move_start.x + new_velocity.x * scale, @move_start.y + new_velocity.y * scale)
    @elapsed_time = 0
    @performing_action = nil
  end
  
  def path_segment_collision(feature, start_point, end_point)
    return nil if feature == self
    super feature, start_point, end_point
  end
  
  def penetration_vector(puck)
    return nil if puck == self
    super puck
  end
  
  def to_json(json = nil)
    json ||= { type: "Puck" }
    json["color"] = @color
    json["translation"] = @translation.to_json
    json["playerId"] = @player_id
    json["queue"] = @queue.collect { |move| move.to_json }
    json["finishOrder"] = @finish_order
    super json
  end
  
  def from_json(json)
    super json
    @color = json["color"]
    @translation = Point.from_json(json["translation"])
    @player_id = json["playerId"]
    @queue = json["queue"].collect { |json| json.key?("type") ? PuckAction.from_json(json) : Point.from_json(json) }
    @finish_order = json["finishOrder"]
  end
  
  private
    def start_next_move
      @performing_action = nil
      while @queue.length > 0
        move = @queue.shift
        if move.is_a? PuckAction
          move.perform self
          @performing_action = move
          if move.pause
            @move_start = nil
            return true
          end
        else
          distance = @move_distances.shift
          if distance
            length = move.length
            if length > distance
              move.scale(distance / length)
            end
            @move_start = @translation
            @move_end = Point.new(@move_start.x + move.x, @move_start.y + move.y)
            @elapsed_time = 0
            return true
          end
        end
      end
      @performing_action = nil
      @move_start = nil
      false
    end
    
    def move_time
      Math.sqrt(-2.0 * @move_start.distance(@move_end) / FRICTION_ACCELERATION)
    end
    
    def step_to(translation)
      collision = get_closest_collision @translation, translation
      unless collision
        if @debug
          puts "#{@player_id} #{@step_count} move #{translation.x} #{translation.y}"
        end
        set_position translation
        return
      end
      @last_collision_feature = collision[2]
      contact = Point.interpolate(@translation, translation, collision[0])
      expected_reflection_distance = @translation.distance(translation) - @translation.distance(contact)
      if @debug
        puts "#{@player_id} #{@step_count} collision #{collision[0]} #{collision[1].x} " +
          "#{collision[1].y} #{@last_collision_feature}"
      end
      set_position collision[1]
      if collision[2].is_a? Puck
        handle_puck_collision collision[2]
        return
      end
      if collision[2].is_a?(LineSegment) && collision[2].role == "finish-line"
        @finish_order = @playfield.next_finish_order
        @collidable = false
        return
      end
      reflection_distance = contact.distance(@translation)
      if reflection_distance < EPSILON
        @move_start = nil
        return
      end
      reflection_ratio = reflection_distance / expected_reflection_distance
      nx = (@translation.x - contact.x) / reflection_distance
      ny = (@translation.y - contact.y) / reflection_distance
      contact_distance = @move_start.distance(contact)
      remaining_distance = @move_start.distance(@move_end) - contact_distance
      @move_end.x = contact.x + reflection_ratio * remaining_distance * nx
      @move_end.y = contact.y + reflection_ratio * remaining_distance * ny
      t2 = @elapsed_time * @elapsed_time
      remaining_distance = contact.distance(@move_end)
      x = remaining_distance + t2 * FRICTION_ACCELERATION / 2.0
      b = 2.0 * FRICTION_ACCELERATION * t2 - 2.0 * x
      c = x * x
      total_distance = (-b + Math.sqrt(b*b - 4.0*c)) / 2.0
      contact_distance = total_distance - remaining_distance
      @move_start.x = contact.x - contact_distance * nx
      @move_start.y = contact.y - contact_distance * ny
    end
    
    def get_closest_collision(start_point, end_point)
      expanded_radius = self.expanded_radius
      min_x = [ start_point.x, end_point.x ].min - expanded_radius
      min_y = [ start_point.y, end_point.y ].min - expanded_radius
      bounds = Rectangle.new(min_x, min_y,
        [ start_point.x, end_point.x ].max - min_x + expanded_radius,
        [ start_point.y, end_point.y ].max - min_y + expanded_radius)
      closest_collision = nil
      @playfield.visit_features_intersecting bounds do |feature|
        collision = feature.path_segment_collision self, start_point, end_point
        if collision && (!closest_collision || collision[0] < closest_collision[0])
          closest_collision = collision
          closest_collision.push feature
        end
      end
      closest_collision
    end
    
    def get_longest_penetration
      expanded_radius = self.expanded_radius
      longest_penetration = nil
      longest_penetration_length = -1.0
      @playfield.visit_features_intersecting @bounds do |feature|
        if feature.intersects_circle(@center, expanded_radius)
          penetration = feature.penetration_vector(self)
          if penetration
            penetration_length = penetration.length
            if penetration_length > longest_penetration_length
              longest_penetration_length = penetration_length
              longest_penetration = penetration            
            end
          end
        end
      end
      longest_penetration
    end
    
    def handle_puck_collision(puck)
      v1 = velocity
      v2 = puck.velocity
      cx = @center.x - puck.center.x
      cy = @center.y - puck.center.y
      length_squared = cx*cx + cy*cy
      vx = v1.x - v2.x
      vy = v1.y - v2.y
      product = (cx*vx + cy*vy) / length_squared
      dx = product * cx
      dy = product * cy
      self.velocity = Point.new(v1.x - dx, v1.y - dy)
      puck.velocity = Point.new(v2.x + dx, v2.y + dy)
    end
end

# Base class for puck actions.
class PuckAction
  
  attr_accessor :pause
  
  def initialize(pause = false)
    @pause = pause
  end
  
  # Creates an action from JSON.  
  def self.from_json(json)
    action = const_get(json["type"]).new
    action.from_json(json)
    action
  end
  
  # Performs the action on the specified puck.
  def perform(puck)
  end
  
  # Steps the action during simulation.
  def step(puck)
  end
  
  # Returns the expected length for this action.
  def get_expected_length(base_length)
    0.0
  end
  
  # Returns the JSON representation of the action.
  def to_json(json = nil)
    json ||= { type: "PuckAction" }
    json
  end
  
  # Loads the action's properties from its JSON representation.
  def from_json(json)
  end
  
end

# An action that extends the next move distance.
class Boost < PuckAction

  attr_accessor :amount

  def initialize(amount = 0.5)
    super()
    @amount = amount
  end
  
  def perform(puck)
    unless puck.move_distances.empty?
      puck.move_distances[0] *= (1.0 + @amount)
    end
  end
  
  def get_expected_length(base_length)
    base_length * @amount
  end
  
  def to_json(json = nil)
    json ||= { type: "Boost" }
    json["amount"] = @amount
    json
  end
  
  def from_json(json)
    @amount = json["amount"]
  end

end

# An action that provides an extra move.
class Extra < PuckAction

  attr_accessor :distance
  
  def initialize(distance = 150)
    super()
    @distance = distance
  end
  
  def perform(puck)
    puck.move_distances.unshift @distance
  end
  
  def get_expected_length(base_length)
    @distance
  end
  
  def to_json(json = nil)
    json ||= { type: "Extra" }
    json["distance"] = @distance
    json
  end
  
  def from_json(json)
    @distance = json["distance"]
  end
  
end

# An action that splits the next move into two.
class Split < PuckAction

  def initialize()
    super()
  end
  
  def perform(puck)
    if puck.move_distances.length > 0
      distance = puck.move_distances.shift / 2.0
      puck.move_distances.unshift distance
      puck.move_distances.unshift distance
    end
  end
  
  def get_expected_length(base_length)
    base_length / 8.0
  end
  
  def to_json(json = nil)
    json ||= { type: "Split" }
    json
  end
  
end

# An action that pauses the puck for a split second.
class Pause < PuckAction

  attr_accessor :steps
  
  def initialize(steps = 30)
    super(true)
    @steps = steps
  end
  
  def perform(puck)
    puck.pause_steps_remaining = @steps
  end
  
  def step(puck)
    (puck.pause_steps_remaining -= 1) > 0
  end
  
  def get_expected_length(base_length)
    base_length / 16.0
  end
  
  def to_json(json = nil)
    json ||= { type: "Pause" }
    json["steps"] = @steps
    json
  end
  
  def from_json(json)
    @steps = json["steps"]
  end
  
end

# An action that pushes other pucks to the side.
class Push < PuckAction

  attr_accessor :amount
  
  def initialize(amount = 1.0)
    super()
    @amount = amount
  end
  
  def perform(puck)
  end
  
  def get_expected_length(base_length)
    base_length * 0.25
  end
  
  def to_json(json = nil)
    json ||= { type: "Push" }
    json["amount"] = @amount
    json
  end
  
  def from_json(json)
    @amount = json["amount"]
  end
  
end

# An action that pulls all other pucks towards this one.
class Pull < PuckAction

  # The maximum step size.
  MAX_STEP_SIZE = 10.0

  attr_accessor :steps, :amount
  
  def initialize(steps = 30, amount = 0.05)
    super(true)
    @steps = steps
    @amount = amount
  end
  
  def perform(puck)
    puck.pause_steps_remaining = @steps
  end
  
  def step(puck)
    return false if (puck.pause_steps_remaining -= 1) <= 0
    puck.playfield.pucks.each do |feature|
      next if feature == puck
      vector = puck.translation.subtracted(feature.translation)
      vector.scale @amount
      length = vector.length
      if length > MAX_STEP_SIZE
        vector.scale(MAX_STEP_SIZE / length)
      end
      feature.translate vector.x, vector.y
      feature.depenetrate
    end
    true
  end
  
  def get_expected_length(base_length)
    base_length * 9.0
  end
  
  def to_json(json = nil)
    json ||= { type: "Pull" }
    json["steps"] = @steps
    json["amount"] = @amount
    json
  end
  
  def from_json(json)
    @steps = json["steps"]
    @amount = json["amount"]
  end
  
end

# An action that scatters other pucks randomly.
class Scatter < PuckAction

  attr_accessor :amount
  
  def initialize(amount = 1.0)
    super()
    @amount = amount
  end
  
  def perform(puck)
  end
  
  def get_expected_length(base_length)
    0.0
  end
  
  def to_json(json = nil)
    json ||= { type: "Scatter" }
    json["amount"] = @amount
    json
  end
  
  def from_json(json)
    @amount = json["amount"]
  end
  
end

# An action that slows down all other pucks.
class Shock < PuckAction

  attr_accessor :amount
  
  def initialize(amount = 1.0)
    super()
    @amount = amount
  end
  
  def perform(puck)
  end
  
  def get_expected_length(base_length)
    0.0
  end
  
  def to_json(json = nil)
    json ||= { type: "Shock" }
    json["amount"] = @amount
    json
  end
  
  def from_json(json)
    @amount = json["amount"]
  end
  
end

# The playfield.
class Playfield

  # The top-level granularity of the hash space used for intersection testing.
  HASH_SPACE_GRANULARITY = 1024.0
  
  # The depth of the hash space.
  HASH_SPACE_DEPTH = 8
 
  attr_reader :path, :pucks
  attr_accessor :starting_lines, :prompt_images, :collided_prompts

  def initialize
    @starting_lines = []
    @prompt_images = []
    @feature_space = HashSpace.new(HASH_SPACE_GRANULARITY, HASH_SPACE_DEPTH)
  end

  # Loads the JSON representation of the playfield.
  def json=(json)
    @starting_lines = []
    json["features"].each do |feature|
      add_feature(Feature.from_json(feature))
    end
    @path = json["path"].collect { |json| [ Point.from_json(json[0]), json[1] ] }
  end
  
  # Adds a feature to the playfield.
  def add_feature(feature)
    feature.playfield = self
    @feature_space.add(feature, feature.bounds) if feature.bounds
  end
  
  # Removes a feature from the playfield.
  def remove_feature(feature)
    feature.playfield = nil
    @feature_space.remove(feature, feature.bounds) if feature.bounds
  end
  
  # Simulates the movement of the specified pucks until they've stopped.
  def simulate(pucks)
    @collided_prompts = []
    @pucks = pucks
    pucks.each do |puck|
      puck.init_simulation
    end
    continuing = true
    last_continuing = true
    while continuing || last_continuing do
      last_continuing = continuing
      continuing = false
      pucks.each do |puck|
        puck_continuing = puck.step_simulation
        continuing ||= puck_continuing
      end
    end
    @pucks = nil
  end
  
  # Returns the next finish order number.
  def next_finish_order
    highest_finish_order = -1
    @pucks.each do |puck|
      highest_finish_order = [ highest_finish_order, puck.finish_order ].max if puck.finish_order
    end
    highest_finish_order + 1
  end
  
  # Returns the total length of the path.
  def path_length
    return 0.0 if @path.length < 2
    length = 0.0
    for index in 0...@path.length - 1
      length += @path[index][0].distance(@path[index + 1][0])
    end
    length
  end
  
  # Returns the progress at the specified point.
  def get_progress(point)
    return 0.0 if @path.length < 2
    closest_distance = Float::MAX
    closest_progress = 0.0
    for index in 0...@path.length - 1
      start_point = @path[index][0]
      end_point = @path[index + 1][0]
      closest = LineSegment.get_closest_point(start_point, end_point, point)
      distance = closest.distance(point)
      if distance < closest_distance
        closest_distance = distance
        closest_progress = @path[index][1] + LineSegment.get_projection(start_point, end_point, point) *
          (@path[index + 1][1] - @path[index][1])
      end
    end
    [ 0.0, closest_progress, 1.0 ].sort[1]  
  end
  
  # Visits the features intersecting the provided bounds.
  def visit_features_intersecting(bounds, &visitor)
    @feature_space.visit_intersecting(bounds, &visitor)
  end
end
