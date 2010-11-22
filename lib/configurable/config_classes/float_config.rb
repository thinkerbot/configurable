module Configurable
  module ConfigClasses
    class FloatConfig < ObjectConfig
      matches Float
      
      def cast(input)
        Float(input)
      end
    end
  end
end