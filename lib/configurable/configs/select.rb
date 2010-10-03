module Configurable
  module Configs
    
    # Represents a config where the input is expected to be one of a specified
    # whitelist.  The default writer will enforce this constraints.
    class Select < Config
      
      # An array of allowed values for the config. Note the writer must do the
      # work of checking and enforcing this constraint.
      attr_reader :options
      
      def initialize(name, default=nil, reader=nil, writer=nil, caster=nil, attrs={})
        super
        @options = attrs[:options] || []
      end
      
      def cast(value)
        value = super(value)
    
        unless options.include?(value)
          raise ArgumentError, "invalid value for #{name}: #{value.inspect}"
        end
    
        value
      end
    end
  end
end