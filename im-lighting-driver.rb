#!/usr/bin/ruby

require 'rubygems'
require '../ruby-artnet/lib/artnet/io.rb'
require '../ruby-artnet/lib/artnet/node.rb'
require 'socket'
require 'lib/im-netreader.rb'
require 'lib/im-log.rb'

class RGBLight
  attr_accessor :uni, :subuni, :start_chan, :r, :g, :b, :h, :s, :v
  attr_reader :r_chan, :g_chan, :b_chan
  
  def initialize(options)
    @uni        = options[:uni]
    @subuni     = options[:subuni]
    @start_chan = options[:start_chan]
    @chan_order = options[:chan_order] || :rgb
    raise ArgumentError, "No start channel given in RGBLight" unless @start_chan
    raise ArgumentError, "Start channel too high in RGBLight" if @start_chan >= 510
    update_chans
    @r = @g = @b = 0
  end
  
  def h=(h)
    @h = h
    update_hsv
  end
  
  def s=(s)
    @s = s
    update_hsv
  end
  
  def v=(v)
    @v = v
    update_hsv
  end
  
  def hsv=(hsv)
    @h = hsv[0]
    @s = hsv[1]
    @v = hsv[2]
    update_hsv
  end
  
  def start_chan=(start_chan)
    raise ArgumentError, "Start channel too high in RGBLight" if start_chan >= 510
    @start_chan = start_chan
    update_chans
  end
  
  def chan_order=(chan_order)
    @chan_order = chan_order
    update_chans
  end
  
  private
  
  def update_hsv
    
    i = (@h/255.to_f * 6).floor;
    f = @h/255.to_f * 6 - i;
    p = @v/255.to_f * (1 - @s/255.to_f);
    q = @v/255.to_f * (1 - f * @s/255.to_f);
    t = @v/255.to_f * (1 - (1 - f) * @s/255.to_f);

    case i % 6
      when 0
        @r = @v/255.to_f
        @g = t
        @b = p
      when 1
        @r = q
        @g = @v/255.to_f
        @b = p
      when 2
        @r = p
        @g = @v/255.to_f
        @b = t
      when 3
        @r = p
        @g = q
        @b = @v/255.to_f
      when 4
        @r = t
        @g = p
        @b = @v/255.to_f
      when 5
        @r = @v/255.to_f
        @g = p
        @b = q
    end
    @r = (r * 255).to_i
    @g = (g * 255).to_i
    @b = (b * 255).to_i
  end
  
  def update_chans
    case @chan_order
      when :rgb
        @r_chan = @start_chan
        @g_chan = @start_chan + 1
        @b_chan = @start_chan + 2
      when :grb
        @g_chan = @start_chan
        @r_chan = @start_chan + 1
        @b_chan = @start_chan + 2
      else
        raise RuntimeError, "Invalid channel order passed to RGBLight"
    end
  end
end

class LightGroup
  attr_accessor :lights
  
  # syntactic sugar to make .each work instead of .lights.each
  def each
    @lights.each do |light|
      yield light
    end
  end
  
  def all_hsv=(hsv)
    #puts "Setting all lights to #{hsv[0]} #{hsv[1]} #{hsv[2]}"
    @lights.each do |light|
      light.hsv = hsv
      #puts "Light colour is now r:#{light.r} g:#{light.g} b:#{light.b} / h:#{light.h} s:#{light.s} v:#{light.v}"
    end
  end
end

class LightingDriver
  attr_accessor :state, :nbr_walls, :vwalls, :hwalls
  attr_reader   :last_discovery, :last_announce
  
  def initialize(options)
    @udp = UDPSocket.new
    @udp_addr = "127.0.0.1"
    @udp_port = 4444
    @nbr_walls = 4
    @vwalls = Array.new(@nbr_walls+1, Array.new(@nbr_walls, nil) )
    @hwalls = Array.new(@nbr_walls, Array.new(@nbr_walls+1, nil) )
    # set up the vertical walls
    for x in 0..@nbr_walls do
      for y in 0..@nbr_walls-1 do
        @vwalls[x][y] = LightGroup.new
      end
    end
    @vwalls[0][0].lights = gen_wall_lights 0, 0, 128*0+1..128*1-3
    @vwalls[0][1].lights = gen_wall_lights 0, 0, 128*1+1..128*2-3
    @vwalls[0][2].lights = gen_wall_lights 0, 0, 128*2+1..128*3-3
    @vwalls[0][3].lights = gen_wall_lights 0, 0, 128*3+1..128*4-3
    @vwalls[1][0].lights = gen_wall_lights 0, 1, 128*0+1..128*1-3
    @vwalls[1][1].lights = gen_wall_lights 0, 1, 128*1+1..128*2-3
    @vwalls[1][2].lights = gen_wall_lights 0, 1, 128*2+1..128*3-3
    @vwalls[1][3].lights = gen_wall_lights 0, 1, 128*3+1..128*4-3
    @vwalls[2][0].lights = gen_wall_lights 0, 2, 128*0+1..128*1-3
    @vwalls[2][1].lights = gen_wall_lights 0, 2, 128*1+1..128*2-3
    @vwalls[2][2].lights = gen_wall_lights 0, 2, 128*2+1..128*3-3
    @vwalls[2][3].lights = gen_wall_lights 0, 2, 128*3+1..128*4-3
    @vwalls[3][0].lights = gen_wall_lights 0, 3, 128*0+1..128*1-3
    @vwalls[3][1].lights = gen_wall_lights 0, 3, 128*1+1..128*2-3
    @vwalls[3][2].lights = gen_wall_lights 0, 3, 128*2+1..128*3-3
    @vwalls[3][3].lights = gen_wall_lights 0, 3, 128*3+1..128*4-3
    @vwalls[4][0].lights = gen_wall_lights 1, 0, 128*0+1..128*1-3
    @vwalls[4][1].lights = gen_wall_lights 1, 0, 128*1+1..128*2-3
    @vwalls[4][2].lights = gen_wall_lights 1, 0, 128*2+1..128*3-3
    @vwalls[4][3].lights = gen_wall_lights 1, 0, 128*3+1..128*4-3
    # set up the horizontal walls
    for x in 0..@nbr_walls-1 do
      for y in 0..@nbr_walls do
        @hwalls[x][y] = LightGroup.new
      end
    end
    @hwalls[0][0].lights = gen_wall_lights 1, 1, 128*0+1..128*1-3
    @hwalls[1][0].lights = gen_wall_lights 1, 1, 128*1+1..128*2-3
    @hwalls[2][0].lights = gen_wall_lights 1, 1, 128*2+1..128*3-3
    @hwalls[3][0].lights = gen_wall_lights 1, 1, 128*3+1..128*4-3
    @hwalls[0][1].lights = gen_wall_lights 1, 2, 128*0+1..128*1-3
    @hwalls[1][1].lights = gen_wall_lights 1, 2, 128*1+1..128*2-3
    @hwalls[2][1].lights = gen_wall_lights 1, 2, 128*2+1..128*3-3
    @hwalls[3][1].lights = gen_wall_lights 1, 2, 128*3+1..128*4-3
    @hwalls[0][2].lights = gen_wall_lights 1, 3, 128*0+1..128*1-3
    @hwalls[1][2].lights = gen_wall_lights 1, 3, 128*1+1..128*2-3
    @hwalls[2][2].lights = gen_wall_lights 1, 3, 128*2+1..128*3-3
    @hwalls[3][2].lights = gen_wall_lights 1, 3, 128*3+1..128*4-3
    @hwalls[0][3].lights = gen_wall_lights 2, 0, 128*0+1..128*1-3
    @hwalls[1][3].lights = gen_wall_lights 2, 0, 128*1+1..128*2-3
    @hwalls[2][3].lights = gen_wall_lights 2, 0, 128*2+1..128*3-3
    @hwalls[3][3].lights = gen_wall_lights 2, 0, 128*3+1..128*4-3
    @hwalls[0][4].lights = gen_wall_lights 2, 1, 128*0+1..128*1-3
    @hwalls[1][4].lights = gen_wall_lights 2, 1, 128*1+1..128*2-3
    @hwalls[2][4].lights = gen_wall_lights 2, 1, 128*2+1..128*3-3
    @hwalls[3][4].lights = gen_wall_lights 2, 1, 128*3+1..128*4-3
    # bring up a new artnet connection
    @artnet = ArtNet::IO.new :network => "2.0.0.0", :netmask => "255.0.0.0"
    @log = options[:logger]
    @last_discovery = Time.at 0
    @last_announce = Time.at 0
    @log.info "iM lighting driver initialized."
  end
  
  def update_all_universes
    for x in 0..@nbr_walls do
      for y in 0..@nbr_walls-1 do
        #puts "Starting light updates for vwall #{x}.#{y}"
        @vwalls[x][y].each do |light|
          #puts "Updating light #{light.start_chan}"
          @artnet.tx_data[light.uni][light.subuni][light.r_chan] = light.r
          @artnet.tx_data[light.uni][light.subuni][light.g_chan] = light.g
          @artnet.tx_data[light.uni][light.subuni][light.b_chan] = light.b
        end
        #puts "Done."
      end
    end
    # FIXME: don't hardcode this
    @artnet.send_update 0, 0
    @artnet.send_update 0, 1
    @artnet.send_update 0, 2
    @artnet.send_update 0, 3
    @artnet.send_update 1, 0
    @artnet.send_update 1, 1
    @artnet.send_update 1, 2
    @artnet.send_update 1, 3
  end
  
  def process_events
    @artnet.process_events
  end
  
  def discover
    @log.debug "Starting node discovery"
    @artnet.poll_nodes
    @last_discovery = Time.new
  end
  
  def announce_nodes
    @log.debug "Announcing #{@artnet.nodes.length} discovered nodes"
    nodeinfo = ""
    @artnet.nodes.each do |node|
      node.swin.each do |port|
        nodeinfo += " #{node.uni}.#{node.subuni}.#{port}"
      end
    end
    send_update "lightnodes #{@artnet.nodes.length}#{nodeinfo}"
    @last_announce = Time.new
  end
  
  private
  
  def gen_wall_lights(uni, subuni, chan_range)
    wall = Array.new
    chan_range.step(3).each do |chan|
      wall << RGBLight.new(:uni => uni, :subuni => subuni, :start_chan => chan)
      #puts "Adding uni #{uni} subuni #{subuni} start chan #{chan}"
    end
    wall
  end
  
  def send_update(packet)
    puts "sending [#{packet}]"
    @udp.send packet, 0, @udp_addr, @udp_port
  end
end

$0 = "iM: Lighting"
log = Logging.new 'LIT'

trap "SIGINT", proc {
  log.info "SIGINT received, shutting down."
  Kernel.exit 0
}

light = LightingDriver.new :logger => log
net_reader = NetReader.new :port => 4448
net_reader.state_callback = lambda {|old_state, new_state|
  light.state = new_state
}

while(true) do
  net_reader.get_data
  light.process_events
  light.discover if Time.new - light.last_discovery > 30  # run a discovery every 30s
  light.announce_nodes if Time.new - light.last_announce > 30 && Time.new - light.last_discovery > 2
  light.update_all_universes
  #puts light.state
  case light.state
    when :attract
      # currently the whole board just flashes random colours for attract mode
      # TODO: make this prettier
      for x in 0..light.nbr_walls do
        for y in 0..light.nbr_walls-1 do
          light.vwalls[x][y].all_hsv = [rand(256), 255, 255]
        end
      end
      for x in 0..light.nbr_walls-1 do
        for y in 0..light.nbr_walls do
          light.hwalls[x][y].all_hsv = [rand(256), 255, 255]
        end
      end
  end
  sleep 0.25
end
