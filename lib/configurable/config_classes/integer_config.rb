module Configurable
  module ConfigClasses
    class IntegerConfig < StringConfig
      matches Integer
      
      def cast(input)
        Integer(input)
      end
    end
  end
end