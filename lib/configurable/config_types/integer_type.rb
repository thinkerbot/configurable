module Configurable
  module ConfigTypes
    class IntegerType < StringType
      matches Integer
      
      def cast(input)
        Integer(input)
      end
    end
  end
end