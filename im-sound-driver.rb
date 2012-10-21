#!/usr/bin/ruby

require 'rubygems'
require 'rubygame'
require 'socket'

include Rubygame

class SoundDriver
  def initialize
    @sounds = Hash.new
    @sounds['buzz'] = Sound.load("sounds/buzz.wav");
  end

  def play(sound)
    @sounds[sound].play
    while(@sounds[sound].playing?) do
      sleep 0.1
    end
  end
end

# NetReader reads from a UDP socket and makes callbacks to the maze driver for various events
class NetReader
  attr_writer :sound_callback
  
  def initialize
    @udp = UDPSocket.new
    @udp.bind("127.0.0.1", 4447)
    @beam_callback  = lambda { }
  end

  def get_data
    while(data = @udp.recvfrom(255)[0]) do
      process_received_data data
        puts "nom nom nom data"
    end
  end
  
  private
  
  def process_received_data(data_in)
    data = data_in.scan(/"[^"]*"|\S+/)
    case data.shift
      when 'sound'
        @sound_callback[data.shift]
    end
  end
end

snd = SoundDriver.new
net_reader = NetReader.new()
net_reader.sound_callback = lambda {|sound|
  snd.play sound
}
while(true) do
  net_reader.get_data
end