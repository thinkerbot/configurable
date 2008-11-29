require 'configuration_parser/option'

class ConfigurationParser
  autoload(:Switch, 'configuration_parser/switch')
  autoload(:Flag, 'configuration_parser/flag')
  autoload(:List, 'configuration_parser/list')
  
  class << self

    # Turns the input string into a short-format option.  Raises
    # an error if the option does not match SHORT_OPTION.  Nils
    # are returned directly.
    #
    #   ConfigurationParser.shortify("-o")         # => '-o'
    #   ConfigurationParser.shortify(:o)           # => '-o'
    #
    def shortify(str)
      return nil if str == nil
      
      str = str.to_s
      str = "-#{str}" unless str[0] == ?-
      unless str =~ SHORT_OPTION && $3 == nil
        raise ArgumentError, "invalid short option: #{str}"
      end
      str
    end

    # Turns the input string into a long-format option.  Underscores
    # are converted to hyphens. Raises an error if the option does
    # not match LONG_OPTION.  Nils are returned directly.
    #
    #   ConfigurationParser.longify("--opt")       # => '--opt'
    #   ConfigurationParser.longify(:opt)          # => '--opt'
    #   ConfigurationParser.longify(:opt_ion)      # => '--opt-ion'
    #
    def longify(str)
      return nil if str == nil
      
      str = str.to_s
      str = "--#{str}" unless str =~ /^--/
      str.gsub!(/_/, '-')
      unless str =~ LONG_OPTION && $3 == nil
        raise ArgumentError, "invalid long option: #{str}"
      end
      str
    end
    
    # Splits and nests compound keys of a hash.
    #
    #   ConfigurationParser.nest('key' => 1, 'compound:key' => 2)
    #   # => {
    #   # 'key' => 1,
    #   # 'compound' => {'key' => 2}
    #   # }
    #
    # Nest does not do any consistency checking, so be aware that results will
    # be ambiguous for overlapping compound keys.
    #
    #   ConfigurationParser.nest('key' => {}, 'key:overlap' => 'value')
    #   # =? {'key' => {}}
    #   # =? {'key' => {'overlap' => 'value'}}
    #
    def nest(hash, split_char=":")
      result = {}
      hash.each_pair do |compound_key, value|
        if compound_key.kind_of?(String)
          keys = compound_key.split(split_char)
          
          unless keys.length == 1
            nested_key = keys.pop
            nested_hash = keys.inject(result) {|target, key| target[key] ||= {}}
            nested_hash[nested_key] = value
            next
          end
        end
        
        result[compound_key] = value
      end
      
      result
    end
  end
  
  OPTION_BREAK = "--"
  
  # Matches a short option
  SHORT_OPTION = /^(-[A-z](:[A-z])*)(=(.*))?$/
  
  ALT_SHORT_OPTION = /^(-[A-z](:[A-z])*)(.+)$/
  
  # Matches a long option
  LONG_OPTION = /^(--[A-z].*?)(=(.*))?$/  # variants: /^--([^=].*?)(=(.*))?$/
  
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
    @options << ""
    @options << str
  end
  
  # Registers the option with self by adding opt to options and mapping
  # the opt switches. Raises an error for conflicting keys and switches.
  def register(opt)
    unless @options.include?(opt)
      # check for conflicts and register
      if options.find {|existing| existing.key == opt.key }
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
    end.join("\n") + "\n"
  end
end