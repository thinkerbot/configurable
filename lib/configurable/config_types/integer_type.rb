module Configurable
  module ConfigTypes
    class IntegerType < ObjectType
      matches Integer
      
      def cast(input)
        Integer(input)
      end
    end
  end
end