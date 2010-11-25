module Configurable
  module ConfigTypes
    class FloatType < ObjectType
      matches Float
      
      def cast(input)
        Float(input)
      end
    end
  end
end