module Configurable
  module ConfigClasses
    class IntegerConfig < ObjectConfig
      matches Integer
      
      def cast(input)
        Integer(input)
      end
    end
  end
end