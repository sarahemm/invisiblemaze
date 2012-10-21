#!/usr/bin/ruby

require 'socket'
require 'maze.rb'

class BeamDriver
  def initialize
    @grid_size = 4
    @udp = UDPSocket.new
    @udp_addr = "127.0.0.1"
    @udp_port = 4444
    @hbeams = Array.new(@grid_size+1) { Array.new(@grid_size+1, :open) }
    @vbeams = Array.new(@grid_size+1) { Array.new(@grid_size+1, :open) }
  end
  
  def set_beam(state, hv, x, y)
    make = (state == :make ? true : false)
    @hbeams[x][y] = make if hv == :h
    @vbeams[x][y] = make if hv == :v
    send_beam_update make, hv, x, y
    send_event "#{hv}beam #{x}.#{y} #{state}"
  end
  
  # send out an update for every beam in the grid, so that the console knows what's up
  def update_all_beams
    for x in 0..@grid_size do
      for y in 0..@grid_size do
        mb = @hbeams[x][y] ? "m" : "b"
        send_beam_update(mb, "h", x, y)
        mb = @vbeams[x][y] ? "m" : "b"
        send_beam_update(mb, "v", x, y)
      end
    end
  end
  
  private
  
  def send_beam_update(make, hv, x, y)
    @udp.send "beam #{make ? "m" : "b"} #{hv} #{x} #{y}", 0, @udp_addr, @udp_port
  end
  
  def send_event(msg)
    @udp.send "event beam-driver \"#{msg}\"", 0, @udp_addr, @udp_port
  end
end

beam = BeamDriver.new()
beam.update_all_beams
hv = :h if ARGV[0] == 'h'
hv = :v if ARGV[0] == 'v'
x = ARGV[1].to_i
y = ARGV[2].to_i
beam.set_beam :break, hv, x, y
sleep 0.5
beam.set_beam :make, hv, x, y
