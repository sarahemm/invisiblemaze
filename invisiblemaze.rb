#!/usr/bin/ruby

require 'rubygems'
require 'lib/im-log.rb'

$0 = 'iM: Controller'
log = Logging.new 'CTL'

def launch_module(mod)
  @running_mods[mod] = Process.fork do
    Process.setsid  # detach from the controlling terminal
    STDIN.reopen "/dev/null"
    File.open("run/im-#{mod.downcase}.pid", 'w') { |f| f.write(Process.pid) }
    Kernel.exec "./im-#{mod.downcase}.rb"
  end
end

def process_running?(pid)
  begin
    Process.getpgid(pid)
    true
  rescue Errno::ESRCH
    false
  end
end

trap "SIGINT", proc {
  puts ""
  log.info "SIGINT received, shutting down all modules..."
  @running_mods.each do |mod, pid|
    log.info "Shutting down #{mod} (pid #{pid})..."
    File.unlink "run/im-#{mod.downcase}.pid"
    Process.kill "INT", pid.to_i
    tries=0
    while(process_running?(pid)) do
      sleep 0.25
      tries += 1
      if(tries == 10) then
        log.info "#{mod} did not exit, killing."
        Process.kill "KILL", pid.to_i
      end
    end
  end
  
  log.info "All modules shut down and unloaded.  Exiting invisibleMaze.";
  exit
}

modules = ['packet-reflector', 'sound-driver', 'lighting-driver', 'beam-driver', 'maze-driver']
@running_mods = Hash.new
modules.each do |mod|
	log.info "Launching #{mod}..."
	@running_mods[mod] = launch_module mod
	# the packet reflector needs to be up before anything else works
	sleep 0.5 if mod == "packet-reflector"
end

log.info "All modules loaded and running."
while(true) do
  sleep 1
  @running_mods.each do |mod, pid|
    next if process_running? pid
    log.warn "#{mod} died, relaunching."
    launch_module mod
  end
end
