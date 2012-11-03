#!/usr/bin/ruby

require 'rubygems'
require 'rubygame'
require 'socket'
require 'lib/im-netreader.rb'

include Rubygame

class SoundDriver
  def initialize
    @udp = UDPSocket.new
    @udp_addr = "127.0.0.1"
    @udp_port = 4444
    
    @sounds = Hash.new
    Dir.open("sounds") do |dir|
      dir.each do |file|
        next unless file.match /\.wav$/
        name = file.sub('.wav', '')
        puts "Loaded sound '#{name}'"
        @sounds[name] = Sound.load("sounds/#{file}");
      end
    end
    puts "iM sound driver initialized."
  end

  def play(sound)
    puts "Playing sound #{sound}..."
    @udp.send "event sound-driver \"Playing sound '#{sound}'\"", 0, @udp_addr, @udp_port
    @sounds[sound].play
    while(@sounds[sound].playing?) do
      sleep 0.1
    end
  end
end

$0 = "iM: Sound"
snd = SoundDriver.new
net_reader = NetReader.new :port => 4447
net_reader.sound_callback = lambda {|sound|
  snd.play sound
}

while(true) do
  net_reader.get_data
end