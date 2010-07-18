module Configurable
  module Configs
    class Switch < Flag
      
      # The negative long switch, determined from long.
      attr_reader :negative_long

      # Initializes a new Switch.  Raises an error if an arg_name is
      # specified for self (as switches are intended to be boolean
      # in nature), or if no long option is specified.
      def initialize(name, default=nil, reader=nil, writer=nil, attrs={})
        super
        raise ArgumentError, "no long specified" unless long
        @negative_long = prefix_long(long, 'no-')
      end
      
      # Returns an array of non-nil switches mapping to self (ie 
      # [long, negative_long, short]).
      def switches
        [long, negative_long, short].compact
      end
      
      def parse(switch, value, argv=[], config={})
        raise "value specified for switch: #{switch}" unless value.nil?
        config[name] = (switch == negative_long ? !default : default)
      end
      
      private

      # helper returning long formatted for to_s
      def long_str # :nodoc:
        long ? prefix_long(long, '[no-]') : ''
      end
    end
  end
end