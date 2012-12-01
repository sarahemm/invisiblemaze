#!/usr/bin/ruby

require 'rubygems'
require './lib/im-log.rb'

$0 = "iM: Heartbeat"
log = Logging.new 'HBT'

trap "SIGINT", proc {
  log.info "SIGINT received, shutting down."
  Kernel.exit 0
}

def blink_led(nbr)
  nbr.times do
    system "echo 1 > /sys/class/leds/led0/brightness"
    sleep 0.1
    system "echo 0 > /sys/class/leds/led0/brightness"
    sleep 0.1
  end
end

while(true) do
  blink_led `pgrep -fc iM`.strip.to_i - 1
  sleep 2
end
