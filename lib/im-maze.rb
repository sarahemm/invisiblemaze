class Maze
  DIRECTIONS = [ [1, 0], [-1, 0], [0, 1], [0, -1] ]
  attr_accessor :vertical_walls, :horizontal_walls, :width, :height
  
  def initialize(options)
    @width = options[:width]
    @height = options[:height]
    @start_x = options[:start_x] ? options[:start_x] : rand(@width)
    @start_y = options[:start_y] ? options[:start_y] : 0
    # check to make sure starting x and y are within the grid
    raise RuntimeError if !coordinate_valid?(@start_x, @start_y)
    if(@start_x != 0 && @start_x != @width-1) then
      # start_y can only be the top or bottom if start_x isn't the left or right
      raise RuntimeError if @start_y != 0 && @start_y != @height-1
    end
        
    # Which walls do exist? Default to "true". Both arrays are
    # one element bigger than they need to be. For example, the
    # @vertical_walls[y][x] is true if there is a wall between
    # (x,y) and (x+1,y). The additional entry makes printing
    # easier.
    @vertical_walls = Array.new(@height+1) { Array.new(@width+1, :unhit) }
    @horizontal_walls = Array.new(@height) { Array.new(@width, :unhit) }
    
    # make the maze end opposite from where it starts
    # TODO: maybe randomize this on the opposite wall or something instead?
    if(@start_x == 0) then
      # starts on left, ends on right
      @end_x = @width-1
      @end_y = @height-1 - @start_y
      # open a hole for the exit
      @vertical_walls[@end_y][@end_x] = :open
    elsif(@start_x == @width) then
      # starts on right, ends on left
      @end_x = 0
      @end_y = @height-1 - @start_y
      # open a hole for the exit
      @vertical_walls[@end_y][@end_x] = :open
    elsif(@start_y == 0) then 
      # starts on top, ends on bottom
      @end_x = @width-1 - @start_x
      @end_y = @height-1
      # open a hole for the exit
      @horizontal_walls[@end_y][@end_x] = :open
    else
      # starts on bottom, ends on top
      @end_x = @width-1 - @start_x
      @end_y = 0
      # open a hole for the exit
      @horizontal_walls[@end_y][@end_x] = :open
    end
    
    puts "Starting at #{@start_x}.#{@start_y}, ending at #{@end_x}.#{@end_y}"
    
    reset_visiting_state
  
    # Generate the maze.
    generate
    self.print
    
    # Add the outer walls
    add_maze_walls
  end
  
  # show the maze in ASCII for debugging
  def print
    # Special handling: print the top line.
    line = "+"
    for x in (0...@width)
      line.concat(x == @start_x && @start_y == 0 ? "   +" : "---+")
    end
    puts line
  
    # For each cell, print the right and bottom wall, if it exists.
    for y in (0...@height)
      if y == @start_y && @start_x == 0 then
        line = " "
      else
        line = "|"
      end
      for x in (0...@width)
        line.concat("   ")
        line.concat(@vertical_walls[y][x] != :open ? "|" : " ")
      end
      puts line
  
      line = "+"
      for x in (0...@width)
        line.concat(@horizontal_walls[y][x] != :open ? "---+" : "   +")
      end
      puts line
    end
  end
  
  private
  
  # Reset the VISITED state of all cells.
  def reset_visiting_state
    @visited = Array.new(@height) { Array.new(@width) }
  end
  
  # Check whether the given coordinate is within the valid range.
  def coordinate_valid?(x, y)
    (x >= 0) && (y >= 0) && (x < @width) && (y < @height)
  end
  
  # Is the given coordinate valid and the cell not yet visited?
  def move_valid?(x, y)
    coordinate_valid?(x, y) && !@visited[y][x]
  end
  
  # Generate the maze.
  def generate
    generate_visit_cell @start_x, @start_y
    reset_visiting_state
  end
  
  # Add top/bottom/left/right walls to the maze arrays.
  def add_maze_walls
    # add the left and right sides
    for wall_y in 0..@height-1 do
      @vertical_walls[wall_y].unshift :unhit
      @vertical_walls[wall_y].push :hit
    end
    # add the top
    @horizontal_walls.unshift Array.new(@width, :unhit)
    # open a hole for the start
    # starts on the top or bottom
    if(@start_y == 0 || @start_y == @height-1) then
      @horizontal_walls[@start_y == @height-1 ? @height : 0][@start_x] = :start
    end
    # starts on the left or right
    if(@start_x == 0 || @start_x == @width-1) then
      @vertical_walls[@start_y][@start_x == @width-1 ? @width : 0] = :start
    end
    # open a hole for the end
    # ends on the top or bottom
    if(@end_y == 0 || @end_y == @height-1) then
      @horizontal_walls[@end_y == @height-1 ? @height : 0][@end_x] = :end
    end
    # ends on the left or right
    if(@end_x == 0 || @end_x == @width-1) then
      @vertical_walls[@end_y][@end_x == @width-1 ? @width : 0] = :end
    end
  end
  
  # Depth-first maze generation.
  def generate_visit_cell(x, y)
    # Mark cell as visited.
    @visited[y][x] = true
  
    # Randomly get coordinates of surrounding cells (may be outside
    # of the maze range, will be sorted out later).
    coordinates = []
    for dir in DIRECTIONS.shuffle
      coordinates << [ x + dir[0], y + dir[1] ]
    end
  
    for new_x, new_y in coordinates
      next unless move_valid?(new_x, new_y)
  
      # Recurse if it was possible to connect the current
      # and the the cell (this recursion is the "depth-first"
      # part).
      connect_cells(x, y, new_x, new_y)
      generate_visit_cell new_x, new_y 
    end
  end
  
  # Try to connect two cells. Returns whether it was valid to do so.
  def connect_cells(x1, y1, x2, y2)
    if x1 == x2
      # Cells must be above each other, remove a horizontal
      # wall.
      @horizontal_walls[ [y1, y2].min ][x1] = :open
    else
      # Cells must be next to each other, remove a vertical
      # wall.
      @vertical_walls[y1][ [x1, x2].min ] = :open
    end
  end
end
