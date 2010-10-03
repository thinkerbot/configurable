module Configurable
  module Configs
    
    # Represents a list style config where the input is expected to be an
    # Array, and each value is in a specified whitelist.  The default writer
    # will enforce these constraints.
    class ListSelect < Select
      def cast(values)
        unless values.kind_of?(Array)
          raise ArgumentError, "invalid value for #{name}: #{values.inspect}"
        end
        
        values.collect! {|value| super(value) } 
      end
    end
  end
end