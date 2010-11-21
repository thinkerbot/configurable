module Configurable
  module ConfigClasses
    class StringConfig < Config
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