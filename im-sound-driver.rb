#!/usr/bin/ruby

require 'rubygems'
require 'rubygame'
require 'socket'
require 'lib/im-netreader.rb'

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

snd = SoundDriver.new
net_reader = NetReader.new()
net_reader.sound_callback = lambda {|sound|
  snd.play sound
}

while(true) do
  net_reader.get_data
end