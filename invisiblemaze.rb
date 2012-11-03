#!/usr/bin/ruby

require 'rubygems'
require 'daemons'
#require 'lib/majel/core/mq'
#require 'lib/majel/core/log'

$0 = 'iM: Controller'
basedir = Dir.pwd

trap "SIGINT", proc {
  print "\nSIGINT received, shutting down...\n"
  @running_mods.each do |mod, app|
    print "Shutting down #{mod}...\n"
    app.stop
    pid = File.open("run/im-#{mod.downcase}.pid", 'r') { |f| f.read }
    File.unlink "run/im-#{mod.downcase}.pid"
    Process.kill "INT", pid.to_i
  end
  print "\nAll modules shut down and unloaded.  Exiting invisibleMaze.\n";
  exit
}
modules = ['packet-reflector', 'sound-driver', 'lighting-driver', 'maze-driver']
@loaded_mods = Hash.new
@running_mods = Hash.new

modules.each do |mod|
	print "Launching #{mod}...\n"
	@running_mods[mod] = Daemons::call({:multiple => true, :app_name => "iM: #{mod.downcase}"}) do
	  Dir.chdir basedir
	  File.open("run/im-#{mod.downcase}.pid", 'w') { |f| f.write(Process.pid) }
	  $stdout.reopen("log/#{mod.downcase}-out.txt", "w")
	  $stderr.reopen("log/#{mod.downcase}-err.txt", "w")
	  Kernel.exec "./im-#{mod.downcase}.rb"
#		mod_class = InvisibleMaze.const_get(mod).const_get('Driver')
#		@loaded_mods[mod] = mod_class.new
#		@loaded_mods[mod].run
	end
end

print "\nAll modules loaded and running.\n"
while(true) do
  sleep 1;
end
