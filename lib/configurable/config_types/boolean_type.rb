module Configurable
  module ConfigTypes
    class BooleanType < StringType
      matches TrueClass, FalseClass
      
      # Casts the input to a boolean ie:
      #
      #   true, 'true'   => true
      #   false, 'false  => false
      #
      # All other inputs raise an ArgumentError.
      def cast(input)
        case input
        when true, false then input
        when 'true'      then true
        when 'false'     then false
        else raise ArgumentError, "invalid value for boolean: #{input.inspect}"
        end
      end
    end
  end
end