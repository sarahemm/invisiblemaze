#!/usr/bin/ruby

require 'rubygems'
require 'rubygame'
require 'socket'
require 'lib/im-netreader.rb'

include Rubygame

class LightingDriver
  def initialize
  end
end

light = LightingDriver.new
net_reader = NetReader.new()
while(true) do
  net_reader.get_data
end