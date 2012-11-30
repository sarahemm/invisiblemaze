#!/usr/bin/ruby

require 'rubygems'
require 'socket'
require 'rubygame'
require 'getoptlong'
require 'lib/im-maze.rb'
require 'lib/im-netreader.rb'
include Rubygame
include Rubygame::Events

# Display is inherited by all other display modules, sets up all common elements
class Display
  attr_reader :base_x, :base_y, :width, :height
  
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
  
  def click(x, y)
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
    beam_ul, beam_lr = get_horiz_beam_rect x, y
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
    beam_ul, beam_lr = get_vert_beam_rect x, y
    filled = true
    filled = colour.pop if colour.length == 4
    if filled then
      surface.draw_box_s(beam_ul, beam_lr, colour);
    else
      surface.draw_box(beam_ul, beam_lr, colour);
    end
  end
  
  # given the x, y of a horizontal beam, returns the pixel upper-left/lower-right rectangle
  def get_horiz_beam_rect(x, y)
    beam_ul = [@hub_spacing/2 + @hub_spacing*x, (@hub_spacing/2 + @hub_spacing*y) - @hub_dia/2, 0]
    beam_lr = [@hub_spacing/2 + @hub_spacing*(x+1), (@hub_spacing/2 + @hub_spacing*y) + @hub_dia/2, 0]
    [beam_ul, beam_lr]
  end

  # given the x, y of a vertical beam, returns the pixel upper-left/lower-right rectangle
  def get_vert_beam_rect(x, y)
    beam_ul = [(@hub_spacing/2 + @hub_spacing*x) - @hub_dia/2, @hub_spacing/2 + @hub_spacing*y, 0]
    beam_lr = [(@hub_spacing/2 + @hub_spacing*x) + @hub_dia/2, @hub_spacing/2 + @hub_spacing*(y+1), 0]
    [beam_ul, beam_lr]
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
    @udp = UDPSocket.new
    @udp_addr = "127.0.0.1"
    @udp_port = 4444
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
  
  # clicking a beam causes a simulated break/make cycle
  def click(x, y)
    super x, y
    for beam_x in (0..@nbr_beams) do
      for beam_y in (0..@nbr_beams-1) do
        beam_ul, beam_lr = get_vert_beam_rect(beam_x, beam_y)
        if(x > beam_ul[0]-10 && x < beam_lr[0]+10 && y > beam_ul[1]-10 && y < beam_lr[1]+10) then
          send_beam_update false, :v, beam_x, beam_y
          send_event "vbeam #{beam_x}.#{beam_y} break"
          sleep 0.5
          send_beam_update true, :v, beam_x, beam_y
          send_event "vbeam #{beam_x}.#{beam_y} make"
          break
        end
      end
    end
    for beam_x in (0..@nbr_beams-1) do
      for beam_y in (0..@nbr_beams) do
        beam_ul, beam_lr = get_horiz_beam_rect(beam_x, beam_y)
        if(x > beam_ul[0]-10 && x < beam_lr[0]+10 && y > beam_ul[1]-10 && y < beam_lr[1]+10) then
          send_beam_update false, :h, beam_x, beam_y
          send_event "hbeam #{beam_x}.#{beam_y} break"
          sleep 0.5
          send_beam_update true, :h, beam_x, beam_y
          send_event "hbeam #{beam_x}.#{beam_y} make"
          break
        end
      end
    end
  end
  
  def send_beam_update(make, hv, x, y)
    @udp.send "beam #{make ? "m" : "b"} #{hv} #{x} #{y}", 0, @udp_addr, @udp_port
  end
  
  def send_event(msg)
    @udp.send "event console-beam \"#{msg}\"", 0, @udp_addr, @udp_port
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

# LightingDisplay shows the status of the connected lighting universes
class LightingDisplay < Display
  def initialize(options)
    super
    @nbr_unis = options[:nbr_unis] || 0
    @unis_seen = Array.new
  end
  
  def draw
    # set up a temporary surface to draw to, before blitting to the screen
    surface = Surface.new([@width, @height]);
    #surface.fill [50, 50, 50]
    # draw our indicators for each universe
    dia = @width/10
    y_spacing = @height/(@nbr_unis+1)
    addr_uni = 0
    (1..@nbr_unis).each do |uni|
      x = @width/2
      y = y_spacing/2+uni*y_spacing
      colour = [255, 0, 0]
      addr_subuni =  (uni-1) / 4
      addr_port   = ((uni-1) % 4) + 1
      colour = [0, 255, 0] if @unis_seen.include? [addr_uni, addr_subuni, addr_port]
      surface.draw_circle_s [x, y, 0], dia, colour
      text_uni = format "%02d", uni.to_s
      draw_text :text => text_uni, :x => x-@body_font.height/2, :y => y-@body_font.height/2, :surface => surface, :font => @body_font
    end
    # draw the title
    text_surface = @title_font.render "Lighting", true, [200, 200, 225]
    text_surface.blit surface, [@width/2-text_surface.width/2, 0]
    # blit the surface into the requested place on the screen
    surface.blit @screen, [@base_x, @base_y], [0, 0, @width, @height]
  end
  
  def discovered_nodes=(node_list)
    @unis_seen.clear
    node_list.each do |uni_info|
      addr_uni, addr_subuni, addr_port = uni_info.split "."
      @unis_seen << [addr_uni.to_i, addr_subuni.to_i, addr_port.to_i]
    end
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

# MAIN #
width = 1024
height = 768

opts = GetoptLong.new(
  [ '--size', '-s', GetoptLong::REQUIRED_ARGUMENT ]
)
opts.each do |opt, arg|
  case opt
    when '--size'
      (width, height) = arg.split("x")
      width  = width.to_i
      height = height.to_i
  end
end

CYCLE_DELAY=0.5
grid_size = 4
screen = Rubygame::Screen.open [width, height]
Rubygame::Surface.autoload_dirs << "images"
TTF.setup
screen.fill :black

# set up each display module
maze_ui     = MazeDisplay.new     :screen => screen, :width => screen.width*0.463, :height => screen.height*0.618, :base_x => screen.width*0.000, :base_y => screen.height*0.014, :nbr_beams => grid_size
beam_ui     = BeamDisplay.new     :screen => screen, :width => screen.width*0.463, :height => screen.height*0.618, :base_x => screen.width*0.537, :base_y => screen.height*0.014, :nbr_beams => grid_size
lighting_ui = LightingDisplay.new :screen => screen, :width => screen.width*0.122, :height => screen.height*0.618, :base_x => screen.width*0.439, :base_y => screen.height*0.014, :nbr_unis  => 12
event_ui    = EventDisplay.new    :screen => screen, :width => screen.width*0.976, :height => screen.height*0.260, :base_x => screen.width*0.012, :base_y => screen.height*0.488

# set up the network reader and all the callbacks for things it can talk to
net_reader = NetReader.new :port => 4445
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
net_reader.lightnodes_callback = lambda { |nodes, node_info|
  lighting_ui.discovered_nodes = node_info
}

@event_queue = Rubygame::EventQueue.new
@event_queue.enable_new_style_events

# main event loop, net_reader gets data and makes callbacks,
# then the display modules each update their displays
while true do
  @event_queue.each do |e|
    next if !e.is_a? Rubygame::Events::MousePressed
    x = e.pos[0]
    y = e.pos[1]
    if(  x > maze_ui.base_x && x < maze_ui.base_x + maze_ui.width \
      && y > maze_ui.base_y && y < maze_ui.base_y + maze_ui.height) then
      maze_ui.click x - maze_ui.base_x, y - maze_ui.base_y
    elsif(  x > beam_ui.base_x && x < beam_ui.base_x + beam_ui.width \
         && y > beam_ui.base_y && y < beam_ui.base_y + beam_ui.height) then
      beam_ui.click x - beam_ui.base_x, y - beam_ui.base_y
    elsif(  x > event_ui.base_x && x < event_ui.base_x + event_ui.width \
         && y > event_ui.base_y && y < event_ui.base_y + event_ui.height) then
      event_ui.click x - event_ui.base_x, y - event_ui.base_y
    end
  end
  
  net_reader.get_data
  beam_ui.draw
  maze_ui.draw
  lighting_ui.draw
  event_ui.draw
  screen.update
  sleep CYCLE_DELAY
end

# TODO: reset the console when the state goes back to :attract