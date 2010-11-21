module Configurable
  module ConfigClasses
    module List
      def cast(values)
        results = []
        values.each {|value| results << super(value) } 
        results
      end
      
      def uncast(values)
        results = []
        values.each {|value| results << super(value) } 
        results
      end
    end
  end
end