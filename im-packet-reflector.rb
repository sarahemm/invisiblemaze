#!/usr/bin/ruby
# since more than one process listening on a port is unreliable (at least on MacOS X), this
# little app just listens on the "reflector" port, and sends anything received to each
# individual driver, each on their own port.

require 'rubygems'
require 'socket'
require 'lib/im-log.rb'

$0 = "iM: Packet Reflector"
log = Logging.new 'PKT'

trap "SIGINT", proc {
  log.info "SIGINT received, shutting down."
  Kernel.exit 0
}

log.info "iM packet reflector initialized."
udp = UDPSocket.new
udp.bind("127.0.0.1", 4444)
beam_callback  = lambda { }
while(data = udp.recvfrom(255)[0]) do
  log.debug(data)
  udp.send data, 0, "127.0.0.1", 4445 # console
  udp.send data, 0, "127.0.0.1", 4446 # maze-driver
  udp.send data, 0, "127.0.0.1", 4447 # sound-driver
  udp.send data, 0, "127.0.0.1", 4448 # lighting-driver
  #udp.send data, 0, "127.0.0.1", 4449 # beam-driver
end
