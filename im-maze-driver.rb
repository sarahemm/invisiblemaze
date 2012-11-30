#!/usr/bin/ruby

require 'socket'
require './lib/im-maze.rb'
require './lib/im-netreader.rb'
require './lib/im-log.rb'

class MazeDriver
  def initialize(options)
    @log = options[:logger]
    @grid_size = 4
    @udp = UDPSocket.new
    @udp_addr = "127.0.0.1"
    @udp_port = 4444
    @state = :init
    self.state = :attract
    # [0] is "most likely", [1] is "possibly still in", stores a 2 element array of x, y
    @player_loc = Array.new(2)
    @log.info "iM maze driver initialized"
  end

  def new_game(start_x, start_y)
    @maze = Maze.new :width => @grid_size, :height => @grid_size, :start_x => start_x, :start_y => start_y
    broadcast_maze
    @player_loc[0] = [start_x, start_y]
    @player_loc[1] = nil
    broadcast_player_loc
    self.state = :ingame
  end
  
  def broadcast_maze
    type_map = Hash.new
    type_map[:open]  = "0 "
    type_map[:unhit] = "1 "
    type_map[:hit]   = "2 "
    type_map[:start] = "3 "
    type_map[:end]   = "4 "
    hdata = ""
    vdata = ""
    for beam_y in 0..@maze.height do
      for beam_x in 0..@maze.width-1 do
        hdata += type_map[@maze.horizontal_walls[beam_y][beam_x]]
      end
    end
    for beam_y in 0..@maze.height-1 do
      for beam_x in 0..@maze.width do
        vdata += type_map[@maze.vertical_walls[beam_y][beam_x]]
      end
    end

    packet = "maze #{@maze.height} #{hdata} #{vdata}"
    send_update packet
  end
  
  def broadcast_player_loc
    # TODO: should figure out what to do with [1]
    send_update "playerloc #{@player_loc[0].join " "}"
  end
  
  def beam_broken(hv, x, y)
    case @state
      when :attract
        send_update "sound mazegenstart"
        sleep 2.25
        self.state = :mazegen
        # TODO: figure out how to not hardcode the timing here, ideally
        send_update "sound mazegen"
        sleep 4.75
        send_update "sound mazegendone"
        self.new_game x, y
        self.state = :ingame
      when :ingame
        wall = @maze.horizontal_walls[y][x] if hv == :h
        wall = @maze.vertical_walls[y][x] if hv == :v
        case wall
          when :hit
            # TODO: this should make sound
            send_event "#{hv}wall #{x}.#{y} was already hit, no action required"
          when :unhit
            # TODO: this should also deduct points once that exists
            @maze.horizontal_walls[y][x] = :hit if hv == :h
            @maze.vertical_walls[y][x]   = :hit if hv == :v
            send_update "sound buzz"
            broadcast_maze  # TODO: this should be an incremental update once that exists
            send_event "#{hv}wall #{x}.#{y} was unhit, is now hit"
          when :open, :start, :end
            send_event "#{hv}wall #{x}.#{y} is open, updating player location"
            @log.debug "Old location #{@player_loc[0].join " "}, broke #{hv}beam #{x}.#{y}"
            if hv == :h && y == @player_loc[0][1] + 1 then
              @player_loc[0][1] += 1
            elsif hv == :h && y == @player_loc[0][1] then
              @player_loc[0][1] -= 1
            elsif hv == :v && x == @player_loc[0][0] + 1 then
              @player_loc[0][0] += 1
            elsif hv == :v && x == @player_loc[0][0] then
              @player_loc[0][0] -= 1
            end
            @log.debug "New location #{@player_loc[0].join " "}, broke #{hv}beam #{x}.#{y}"
            broadcast_player_loc
        end
    end
  end
  
  private
  
  def state=(new_state)
    @log.debug "state changed from #{@state} to #{new_state}"
    send_event "state changed from #{@state} to #{new_state}"
    send_update "state #{@state} #{new_state}"
    @state = new_state
  end
  
  def send_update(packet)
    @udp.send packet, 0, @udp_addr, @udp_port
  end
  
  def send_event(msg)
    @udp.send "event maze-driver \"#{msg}\"", 0, @udp_addr, @udp_port
  end
end

$0 = "iM: Maze Logic"
log = Logging.new 'MAZ'

trap "SIGINT", proc {
  log.info "SIGINT received, shutting down."
  Kernel.exit 0
}

maze = MazeDriver.new :logger => log
net_reader = NetReader.new :port => 4446
net_reader.beam_callback = lambda {|make, hv, x, y|
  maze.beam_broken hv, x, y if !make
}

while(true) do
  net_reader.get_data
  sleep 0.5
end
