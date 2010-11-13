module Configurable
  module ConfigTypes
    class FloatType < StringType
      matches Float
      
      def cast(input)
        Float(input)
      end
    end
  end
end