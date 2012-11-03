require 'rubygems'
require 'log4r'

class Logging
  def initialize(name)
    @logger = Log4r::Logger.new name
    fmt = Log4r::PatternFormatter.new :pattern => "%d [%c] %l\t%M"
    @logger.outputters = Log4r::StdoutOutputter.new 'console', :formatter => fmt
    @logger.level = 2
  end
  
  def warn(msg)
    @logger.warn msg
  end
  
  def info(msg)
    @logger.info msg
  end
  
  def debug(msg)
    @logger.debug msg
  end  
end