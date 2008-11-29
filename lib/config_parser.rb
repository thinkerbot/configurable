require 'config_parser/option'
require 'config_parser/switch'
require 'config_parser/flag'

class ConfigParser 
  include Utils
  
  attr_reader :switches
  
  def initialize
    @options = []
    @switches = {}
  end
  
  def options
    @options.select do |opt|
      opt.kind_of?(Option)
    end
  end
  
  def separator(str)
    @options << str
  end
  
  # Registers the option with self by adding opt to options and mapping
  # the opt switches. Raises an error for conflicting keys and switches.
  def register(opt)
    unless @options.include?(opt)
      # check for conflicts and register
      if @options.find {|existing| existing.key == opt.key }
        raise ArgumentError, "key is already set by a different option: #{opt.key}"
      end
      @options << opt
    end
    
    opt.switches.each do |switch|
      case @switches[switch]
      when opt then next
      when nil then @switches[switch] = opt
      else raise ArgumentError, "switch is already mapped to a different option: #{switch}"
      end
    end
    
    opt
  end
  
  def on(key, value=nil, options={}, &block)
    klass = case options[:type]
    when :flag then Flag
    when :switch then Switch
    when :list then List
    else Option
    end
    
    register klass.new(key, value, options, &block)
  end
  
  def parse(argv=ARGV)
    parse!(argv.dup)
  end
  
  def parse!(argv=ARGV)
    config = {}
    args = []
    
    while !argv.empty?
      arg = argv.shift
      
      # determine if the arg is an option
      unless arg.kind_of?(String) && arg[0] == ?-
        args << arg
        next
      end
      
      # add the remaining args and break
      # for the option break
      if arg == OPTION_BREAK
        args.concat(argv)
        break
      end
      
      # split the arg...
      # switch= $1
      # value = $4 if SHORT_OPTION, $3 otherwise
      arg =~ LONG_OPTION || arg =~ SHORT_OPTION || arg =~ ALT_SHORT_OPTION 
      
      # lookup the option
      unless option = @switches[$1]
        raise "unknown option: #{$1}"
      end
      
      option.parse($1, $4 || $3, argv, config)
    end
    
    # insert defaults as necessary and process values
    @options.each do |option|
      next if option.kind_of?(String)
      option.process(config)
    end

    [config, args]
  end
  
  def to_s
    @options.collect do |option|
      option.to_s
    end.join("\n")
  end
end