#!/usr/bin/ruby

require 'rubygems'
require 'socket'
require 'serialport'
require './lib/im-log.rb'

class BeamDriver
  def initialize(options = Hash.new)
    @log = options[:logger]
    @grid_size = 4
    @udp = UDPSocket.new
    @udp_addr = "127.0.0.1"
    @udp_port = 4444
    @hbeams = Array.new(@grid_size+1) { Array.new(@grid_size+1, :open) }
    @vbeams = Array.new(@grid_size+1) { Array.new(@grid_size+1, :open) }
    @log.info "iM beam driver initialized."
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
    @log.debug "Sending beam update: beam #{make ? "m" : "b"} #{hv} #{x} #{y}"
  end
  
  def send_event(msg)
    @udp.send "event beam-driver \"#{msg}\"", 0, @udp_addr, @udp_port
  end
end

class BeamHardwareInterface
  def initialize(options = Hash.new)
    @log = options[:logger]
    @device = options[:device]
    baudrate = options[:speed] || 115200
    databits = options[:databits] || 8
    stopbits = options[:stopbits] || 1
    raise RuntimeError "No device specified" if !@device
    @port = SerialPort.new(@device, baudrate, databits, stopbits, SerialPort::NONE)
    begin
      @port.read_nonblock 65535
    rescue Errno::EAGAIN
      return
    end
  end
  
  def get_data
    beam = @port.readbyte
    raw_state = @port.readbyte
    @log.debug "Received update: 0x#{beam.to_s(16)} 0x#{raw_state.to_s(16)}"
    raise FormatError if raw_state != 0x00 && raw_state != 0x01
    state = raw_state == 0 ? :break : :make
    return {:beam => beam, :state => state}
  end
end

$0 = "iM: Beam"
log = Logging.new 'LZR'

trap "SIGINT", proc {
  log.info "SIGINT received, shutting down."
  Kernel.exit 0
}

nbr_beams = 4
hw = BeamHardwareInterface.new :device => "/dev/tty.usbmodem621", :logger => log
beam = BeamDriver.new :logger => log
beam.update_all_beams
while(true) do
  sleep 0.1
  beaminfo = hw.get_data
  y = beaminfo[:beam] / nbr_beams
  x = beaminfo[:beam] % nbr_beams
  # x is serpentine, so flip it for odd numbered rows
  x = nbr_beams-1 - x if y % 2 == 1
  state_word = beaminfo[:state] == :make ? "make" : "break"
  log.info "Beam #{state_word}: #{x}.#{y}"
  beam.set_beam beaminfo[:state], :h, x, y
end
