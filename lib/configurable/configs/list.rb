module Configurable
  module Configs
    
    # Represents a list style config where the input is expected to be an
    # Array.  The default writer will enforce this constraint.
    class List < Config
      def cast(values)
        unless values.kind_of?(Array)
          raise ArgumentError, "invalid value for #{name}: #{values.inspect}"
        end
        
        values.collect! {|value| super(value) } 
      end
    end
  end
end