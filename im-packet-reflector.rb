#!/usr/bin/ruby

require 'socket'

udp = UDPSocket.new
udp.bind("127.0.0.1", 4444)
beam_callback  = lambda { }
while(data = udp.recvfrom(255)[0]) do
  udp.send data, 0, "127.0.0.1", 4445
  udp.send data, 0, "127.0.0.1", 4446
  udp.send data, 0, "127.0.0.1", 4447
end
