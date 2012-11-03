#!/usr/bin/ruby

require 'rubygems'

$0 = 'iM: Controller'
basedir = Dir.pwd

trap "SIGINT", proc {
  print "\nSIGINT received, shutting down...\n"
  @running_mods.each do |mod|
    print "Shutting down #{mod}...\n"
    pid = File.open("run/im-#{mod.downcase}.pid", 'r') { |f| f.read }
    File.unlink "run/im-#{mod.downcase}.pid"
    Process.kill "INT", pid.to_i
  end
  print "\nAll modules shut down and unloaded.  Exiting invisibleMaze.\n";
  exit
}

modules = ['packet-reflector', 'sound-driver', 'lighting-driver', 'maze-driver']
@running_mods = Array.new
modules.each do |mod|
	print "Launching #{mod}...\n"
	@running_mods << mod
	Process.fork do
	  Dir.chdir basedir
	  File.open("run/im-#{mod.downcase}.pid", 'w') { |f| f.write(Process.pid) }
	  #$stdout.reopen("log/#{mod.downcase}-out.txt", "w")
	  #$stderr.reopen("log/#{mod.downcase}-err.txt", "w")
	  Kernel.exec "./im-#{mod.downcase}.rb"
	end
end

print "\nAll modules loaded and running.\n"
while(true) do
  sleep 1;
end
