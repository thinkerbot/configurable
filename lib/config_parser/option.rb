class ConfigParser
  module Utils
    module_function
    OPTION_BREAK = "--"
    
    # Matches a short option
    SHORT_OPTION = /^(-[A-z])(=?(.+))?$/
    
    # Turns the input string into a short-format option.  Raises
    # an error if the option does not match SHORT_OPTION.  Nils
    # are returned directly.
    #
    #   Utils.shortify("-o")         # => '-o'
    #   Utils.shortify(:o)           # => '-o'
    #
    def shortify(str)
      return nil if str == nil
      
      str = str.to_s
      str = "-#{str}" unless str[0] == ?-
      unless str =~ ConfigParser::SHORT_OPTION && ($3 == nil || $3.empty?)
        raise ArgumentError, "invalid short option: #{str}"
      end
      str
    end
    
    # Matches a long option
    LONG_OPTION = /^(--[A-z].*?)(=(.*))?$/  # variants: /^--([^=].*?)(=(.*))?$/
    
    # Turns the input string into a long-format option.  Underscores
    # are converted to hyphens. Raises an error if the option does
    # not match LONG_OPTION.  Nils are returned directly.
    #
    #   Utils.longify("--opt")       # => '--opt'
    #   Utils.longify(:opt)          # => '--opt'
    #   Utils.longify(:opt_ion)      # => '--opt-ion'
    #
    def longify(str)
      return nil if str == nil
      
      str = str.to_s
      str = "--#{str}" unless str =~ /^--/
      str.gsub!(/_/, '-')
      unless str =~ ConfigParser::LONG_OPTION && ($3 == nil || $3.empty?)
        raise ArgumentError, "invalid long option: #{str}"
      end
      str
    end
  end
  
  class Option
    include Utils
    
    attr_reader :key
    attr_reader :default  # the default value
    attr_reader :long
    attr_reader :short
    attr_reader :desc     
    attr_reader :block    # values passed to block, if given.  result collected
    
    def initialize(key, default, options={}, &block)
      @key = key
      @default = default
      @long = longify(options.has_key?(:long) ? options[:long] : key)
      @short = shortify(options[:short])
      @desc = options[:desc]
      @block = block
    end
    
    # Returns an array of non-nil switches mapping to this option 
    # (ie [long, short]).  May be overridden in subclasses.
    def switches
      [long, short].compact
    end
    
    # Selects the value or the shifts a value off of argv and sets
    # that value in config.  
    #
    # Parse is a hook for fancier ways of determining an option
    # value and/or setting the value in config.  Parse recieves 
    # the switch (ie long or short) mapping to self for subclasses
    # that need it (ex the Switch class).
    def parse(switch, value, argv, config)
      config[key] = (value || (argv.empty? ? raise("no value provided for: #{switch}") : argv.shift))
    end
    
    # Processes the config[key] value by passing it to the block,
    # if given, and resetting it in config.  The default value
    # will be used if config does not have a key entry.
    def process(config)
      value = config.has_key?(key) ? config[key] : default
      config[key] = block ? block.call(value) : value
    end
    
    def to_s
      "#{short}, #{long} #{default_str}  #{desc}"
    end
  end
end