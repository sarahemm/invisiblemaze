#!/usr/bin/ruby

require 'socket'

# since more than one process listening on a port is unreliable (at least on MacOS X), this
# little app just listens on the "reflector" port, and sends anything received to each
# individual driver, each on their own port.
$0 = "iM: Packet Reflector"
udp = UDPSocket.new
udp.bind("127.0.0.1", 4444)
beam_callback  = lambda { }
while(data = udp.recvfrom(255)[0]) do
  udp.send data, 0, "127.0.0.1", 4445 # console
  udp.send data, 0, "127.0.0.1", 4446 # maze-driver
  udp.send data, 0, "127.0.0.1", 4447 # sound-driver
  udp.send data, 0, "127.0.0.1", 4448 # lighting-driver
  #udp.send data, 0, "127.0.0.1", 4449 # beam-driver
end
