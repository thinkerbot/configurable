module Configurable
  module ConfigTypes
    class StringType < ObjectType
      matches String
      
      def cast(input)
        String(input)
      end
      
      def uncast(value)
        value.to_s
      end
    end
  end
end