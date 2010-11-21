module Configurable
  module ConfigClasses
    class FloatConfig < StringConfig
      matches Float
      
      def cast(input)
        Float(input)
      end
    end
  end
end