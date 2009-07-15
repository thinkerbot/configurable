class ConfigParser
  
  # Switch represents a special type of Option where both a positive
  # (--switch) and negative (--no-switch) version of long should
  # map to self.  A short may be specified for Switch; it will always
  # be treated like the positive switch.
  class Switch < Option
    
    # The negative long switch, determined from long.
    attr_reader :negative_long
    
    # Initializes a new Switch.  Raises an error if an arg_name is
    # specified for self (as switches are intended to be boolean
    # in nature), or if no long option is specified.
    def initialize(options={})
      super
      raise ArgumentError, "arg_name specified for switch: #{arg_name}" if arg_name
      raise ArgumentError, "no long specified" unless long
      @negative_long = Utils.prefix_long(long, 'no-')
    end
    
    # Returns an array of non-nil switches mapping to self (ie 
    # [long, negative_long, short]).
    def switches
      [long, negative_long, short].compact
    end
    
    # Calls the block with false if the negative long is specified,
    # or calls the block with true in all other cases.  Raises an
    # error if a value is specified.
    def parse(switch, value, argv)
      raise "value specified for switch: #{switch}" if value
      value = (switch == negative_long ? false : true)
      block ? block.call(value) : value
    end

    private
    
    # helper returning long formatted for to_s
    def long_str # :nodoc:
      long ? Utils.prefix_long(long, '[no-]') : ''
    end
  end
end