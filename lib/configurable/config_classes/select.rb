module Configurable
  module ConfigClasses
    
    # Represents a config where the input is in a specified whitelist.
    class Select < Config
      
      # An array of allowed values for the config, enforced on cast.
      attr_reader :options
      
      def initialize(key, attrs={})
        super
        @options = attrs[:options] ||= []
      end
      
      # Casts the value using caster and checks the value is in options.
      def cast(value)
        value = super(value)
    
        unless options.include?(value)
          raise ArgumentError, "invalid value for config: #{value.inspect} (#{name})"
        end
    
        value
      end
    end
  end
end