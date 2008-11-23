require 'configurable'

class ConfigParser 
  attr_reader :configurations
  
  def on(key, value=nil, options={}, &block)
    config()
  end
  
  def parse(argv=ARGV)
    parse!(argv.dup)
  end
  
  def parse!(argv=ARGV)
  end
end