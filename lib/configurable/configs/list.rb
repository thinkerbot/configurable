module Configurable
  module Configs
    
    # Represents a list style config where the input is expected to be an
    # Array.
    class List < Config
      
      # Validates the input is an array and casts each value using caster.
      def cast(values)
        unless values.kind_of?(Array)
          raise ArgumentError, "invalid value for config: #{values.inspect} (#{name})"
        end
        
        values.collect {|value| super(value) } 
      end
    end
  end
end