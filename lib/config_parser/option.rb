require 'config_parser/utils'

class ConfigParser  
  class Option

    attr_reader :short 
    attr_reader :long
    attr_reader :arg_name
    attr_reader :desc     
    attr_reader :block
    
    def initialize(options={}, &block)
      @short = Utils.shortify(options[:short])
      @long = Utils.longify(options[:long])
      @arg_name = options[:arg_name]
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
    def parse(switch, value, argv)
      if arg_name
        unless value
          raise "no value provided for: #{switch}" if argv.empty?
          value = argv.shift
        end
        block ? block.call(value) : value
      else
        raise "value specified for flag" if value
        block ? block.call : nil
      end
    end

    def to_s
      short_str = short ? short + ',' : '   '
      "%-37s%-43s" % ["    #{short_str} #{long} #{arg_name}", desc]
    end
  end
end