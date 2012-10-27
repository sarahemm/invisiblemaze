#!/usr/bin/ruby

require 'rubygems'
require 'socket'
require 'rubygame'
require 'lib/im-maze.rb'
require 'lib/im-netreader.rb'
include Rubygame
include Rubygame::Events

# Display is inherited by all other display modules, sets up all common elements
class Display
  def initialize(options)
    options[:base_x] = 0 if !options[:base_x]
    options[:base_y] = 0 if !options[:base_y]
    options[:width] = 1024 if !options[:width]
    options[:height] = 768 if !options[:height]
    @screen = options[:screen]
    @base_x = options[:base_x]
    @base_y = options[:base_y]
    @width  = options[:width]
    @height = options[:height]
    @title_font = TTF.new "fonts/title.ttf", (@width+@height)/2/20
    @body_font  = TTF.new "fonts/body.ttf", (@width+@height)/2/30
  end
  
  private
  
  def draw_text options
    text_surface = nil
    return nil unless options[:text] != ""
    line_nbr = 0
    options[:text].each_line do |line|
      text_surface = options[:font].render line.chomp, true, [255, 255, 255]
      x = options[:x] == :center ? @width/2-text_surface.width/2   : options[:x]
      y = options[:y] == :center ? @height/2-text_surface.height/2 : options[:y]
      text_surface.blit options[:surface], [x, y + line_nbr*options[:font].line_skip]
      line_nbr += 1
    end
  end
end

# GridDisplay is inherited by other display modules that need to show the grid
class GridDisplay < Display
  def initialize(options)
    super
    options[:nbr_beams] = 5 if !options[:nbr_beams]
    @height = options[:height]
    @nbr_beams = options[:nbr_beams]
    @hub_dia = @width/150
    @beam_width = @hub_dia
    @hub_spacing = @height/(@nbr_beams+1)
  end
  
  def draw_horiz_beam(surface, x, y, colour = [255, 0, 0])
    beam_ul = [@hub_spacing/2 + @hub_spacing*x, (@hub_spacing/2 + @hub_spacing*y) - @hub_dia/2, 0]
    beam_lr = [@hub_spacing/2 + @hub_spacing*(x+1), (@hub_spacing/2 + @hub_spacing*y) + @hub_dia/2, 0]
    filled = true
    filled = colour.pop if colour.length == 4
    if filled then
      surface.draw_box_s(beam_ul, beam_lr, colour);
    else
      surface.draw_box(beam_ul, beam_lr, colour);
    end
  end

  def draw_vert_beam(surface, x, y, colour = [255, 0, 0])
    beam_ul = [(@hub_spacing/2 + @hub_spacing*x) - @hub_dia/2, @hub_spacing/2 + @hub_spacing*y, 0]
    beam_lr = [(@hub_spacing/2 + @hub_spacing*x) + @hub_dia/2, @hub_spacing/2 + @hub_spacing*(y+1), 0]
    filled = true
    filled = colour.pop if colour.length == 4
    if filled then
      surface.draw_box_s(beam_ul, beam_lr, colour);
    else
      surface.draw_box(beam_ul, beam_lr, colour);
    end
  end
  
  def draw_hub(surface, x, y, colour = [255, 255, 255])
    surface.draw_circle_s([@hub_spacing/2 + x * @hub_spacing, @hub_spacing/2 + y * @hub_spacing, 0], @hub_spacing/12, colour)
  end
end

# BeamDisplay shows the laser beams and which are broken/not broken from the beam driver
class BeamDisplay < GridDisplay
  attr_accessor :vbeams, :hbeams
  
  def initialize options
    super
    @vbeams  = Array.new(@nbr_beams+1) { Array.new(@nbr_beams+1, false) }
    @hbeams = Array.new(@nbr_beams+1) { Array.new(@nbr_beams+1, false) }
  end
    
  def draw
    # set up a temporary surface to draw to, before blitting to the screen
    surface = Surface.new([@width, @height]);
    # draw the beams
    for beam_x in (0..@nbr_beams) do
      for beam_y in (0..@nbr_beams) do
        draw_vert_beam(surface, beam_x, beam_y) if beam_y < @nbr_beams && @vbeams[beam_x][beam_y]
        draw_horiz_beam(surface, beam_x, beam_y) if beam_x < @nbr_beams && @hbeams[beam_x][beam_y]
      end
    end
    # draw the hubs
    for hub_x in (0..@nbr_beams+1) do
      for hub_y in (0..@nbr_beams+1) do
        draw_hub(surface, hub_x, hub_y)
      end
    end
    # draw the title
    text_surface = @title_font.render "Laser Beam Monitoring", true, [200, 200, 225]
    text_surface.blit surface, [@hub_spacing/2+(@hub_spacing*@nbr_beams)/2-text_surface.width/2, 0]
    # blit the surface into the requested place on the screen
    surface.blit @screen, [@base_x, @base_y], [0, 0, @width, @height]
  end
end

# MazeDisplay shows the maze itself and which walls are visible/invisible from the maze driver
class MazeDisplay < GridDisplay
  attr_accessor :vertical_walls, :horizontal_walls, :player_location
  
  def initialize options
    super
    @vertical_walls = Array.new
    @horizontal_walls = Array.new
    @player_location = Array.new 2
  end
  
  def draw
    # possible colours for walls, 4th element is whether to fill in the wall
    wall_colours = Hash.new
    wall_colours[:open] = [0, 0, 0, false]
    wall_colours[:unhit] = [50, 50, 50, true]
    wall_colours[:hit] = [175, 175, 255, true]
    wall_colours[:start] = [100, 100, 255, false]
    wall_colours[:end] = [100, 255, 100, false]
    # set up a temporary surface to draw to, before blitting to the screen
    surface = Surface.new([@width, @height]);
    # draw the horizontal beams
    for beam_x in (0..@nbr_beams) do
      for beam_y in (0..@nbr_beams) do
        next unless (defined? horizontal_walls[beam_y][beam_x]) && horizontal_walls[beam_y][beam_x] != nil
        draw_horiz_beam(surface, beam_x, beam_y, wall_colours[horizontal_walls[beam_y][beam_x]])
      end
    end
    # draw the vertical beams
    for beam_x in (0..@nbr_beams) do
      for beam_y in (0..@nbr_beams-1) do
        next unless (defined? vertical_walls[beam_y][beam_x]) && vertical_walls[beam_y][beam_x] != nil
        draw_vert_beam(surface, beam_x, beam_y, wall_colours[vertical_walls[beam_y][beam_x]])
      end
    end
    # draw the hubs
    for hub_x in (0..@nbr_beams+1) do
      for hub_y in (0..@nbr_beams+1) do
        draw_hub(surface, hub_x, hub_y)
      end
    end
    # draw the player (if they're on the board)
    draw_player surface, @player_location[0], @player_location[1] if @player_location[0]
    # draw the title
    text_surface = @title_font.render "Maze Monitoring", true, [200, 200, 225]
    text_surface.blit surface, [@hub_spacing/2+(@hub_spacing*@nbr_beams)/2-text_surface.width/2, 0]
    # blit the surface into the requested place on the screen
    surface.blit @screen, [@base_x, @base_y], [0, 0, @width, @height]
  end
  
  private 
  
  def draw_player(surface, x, y, colour = [0, 255, 0])
    orig_player = Surface["player-g.png"]
    player = orig_player.zoom_to(@hub_spacing/1.2, @hub_spacing/1.2, true)
    player.blit surface, [@hub_spacing/2+x*@hub_spacing+@hub_spacing/2-player.width/2, @hub_spacing/2+y*@hub_spacing+@hub_spacing/2-player.height/2], [0, 0, player.width, player.height]
  end
end

# EventDisplay shows a scrolling ticker of events from other drivers
class EventDisplay < Display
  def initialize(options)
    super
    @events = Array.new
  end
  
  def draw
    # set up a temporary surface to draw to, before blitting to the screen
    surface = Surface.new([@width, @height]);
    # draw our list of events
    draw_text(:text => @events.join("\n"), :x => 25, :y => 50, :surface => surface, :font => @body_font);
    # draw the title
    text_surface = @title_font.render "Event Log", true, [200, 200, 225]
    text_surface.blit surface, [@width/2-text_surface.width/2, 0]
    # blit the surface into the requested place on the screen
    surface.blit @screen, [@base_x, @base_y], [0, 0, @width, @height]
  end
  
  def add_event(from, msg)
    @events.unshift("#{Time.new.strftime("%H:%M:%S")} #{from}: #{msg}")
    @events.pop if @events.length == 9  # keep a rolling list of the last 8 events
  end
end

CYCLE_DELAY=0.5
grid_size = 4
screen = Rubygame::Screen.open [1024, 768]
Rubygame::Surface.autoload_dirs << "images"
TTF.setup
screen.fill :black

# set up each display module
maze_ui = MazeDisplay.new   :screen => screen, :width => 500,  :height => 500, :base_x => 0,   :base_y => 15, :nbr_beams => grid_size
beam_ui = BeamDisplay.new   :screen => screen, :width => 500,  :height => 500, :base_x => 525, :base_y => 15, :nbr_beams => grid_size
event_ui = EventDisplay.new :screen => screen, :width => 1000, :height => 200, :base_x => 12,  :base_y => 500

# set up the network reader and all the callbacks for things it can talk to
net_reader = NetReader.new
net_reader.beam_callback = lambda { |make, hv, x, y|
  beam_ui.hbeams[x][y] = make if hv == :h
  beam_ui.vbeams[x][y] = make if hv == :v
}
net_reader.maze_callback = lambda { |hwalls, vwalls|
  maze_ui.horizontal_walls = hwalls
  maze_ui.vertical_walls = vwalls
}
net_reader.event_callback = lambda { |from, msg|
  event_ui.add_event from, msg
}
net_reader.loc_callback = lambda { |x, y|
  maze_ui.player_location = [x, y]
}
# main event loop, net_reader gets data and makes callbacks,
# then the display modules each update their displays
while true do
  net_reader.get_data
  beam_ui.draw
  maze_ui.draw
  event_ui.draw
  screen.update
  sleep CYCLE_DELAY
end