# NetReader reads from a UDP socket and makes callbacks to the driver for various events
class NetReader
  attr_writer :beam_callback, :maze_callback, :event_callback, :loc_callback, :sound_callback, :state_callback
  
  def initialize(options = Hash.new)
    @port = options[:port] || 4444
    @udp = UDPSocket.new
    @udp.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEPORT, true)
    @udp.bind("127.0.0.1", @port)
    @beam_callback  = lambda { }
    @maze_callback  = lambda { }
    @event_callback = lambda { }
    @loc_callback   = lambda { }
    @sound_callback = lambda { }
    @state_callback = lambda { }
  end
  
  def get_data(options = Hash.new)
    begin
      if(options[:blocking]) then
        until !(data = @udp.recvfrom(255)[0]) do
          process_received_data data
        end
      else
        until !(data = @udp.recvfrom_nonblock(255)[0]) do
          process_received_data data
        end
      end
    rescue Errno::EAGAIN
      # no data to process!
      return nil
    end
  end
  
  private
  
  def process_received_data(data_in)
    data = data_in.scan(/"[^"]*"|\S+/)
    case data.shift
      when 'beam'
        make = data.shift == 'm' ? true : false
        hv = data.shift == 'h' ? :h : :v
        @beam_callback[make, hv, data.shift.to_i, data.shift.to_i]
      when 'event'
        from = data.shift
        msg = data.shift
        # strip off quotes if they're there
        msg = msg[1..-1].reverse[1..-1].reverse if msg[0..0] = "\""
        @event_callback[from, msg]
      when 'maze'
        type_map = Array.new
        type_map[0] = :open
        type_map[1] = :unhit
        type_map[2] = :hit
        type_map[3] = :start
        type_map[4] = :end
        nbr_beams = data.shift.to_i
        vbeams  = Array.new(nbr_beams+1) { Array.new(nbr_beams+1, :open) }
        hbeams = Array.new(nbr_beams+1) { Array.new(nbr_beams+1, :open) }
        for beam_y in 0..nbr_beams do
          for beam_x in 0..nbr_beams-1 do
            hbeams[beam_y][beam_x] = type_map[data.shift.to_i]
          end
        end
        for beam_y in 0..nbr_beams-1 do
          for beam_x in 0..nbr_beams do
            vbeams[beam_y][beam_x] = type_map[data.shift.to_i]
          end
        end
        @maze_callback[hbeams, vbeams]
      when 'playerloc'
        @loc_callback[data.shift.to_i, data.shift.to_i]
      when 'sound'
        @sound_callback[data.shift]
      when 'state'
        @state_callback[data.shift.to_sym, data.shift.to_sym]
    end
  end
end
