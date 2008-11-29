require 'config_parser/utils'

class ConfigParser  
  class Option
    include Utils
    
    attr_reader :key
    attr_reader :default  
    attr_reader :long
    attr_reader :short
    attr_reader :desc     
    attr_reader :block
    
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