module Configurable
  module ConfigClasses
    
    # Represents a list style config where the input is expected to be an
    # Array.
    class List < Config
      
      # Validates the input is an array and casts each value using caster.
      def cast(values)
        results = []
        values.each {|value| results << super(value) } 
        results
      end
      
      # Uncasts each value using uncaster.
      def uncast(values)
        results = []
        values.each {|value| results << super(value) } 
        results
      end
      
      def errors(values)
        output = []
        
        values.each do |value|
          if errors = super(value)
            output.concat(errors)
          end
        end
        
        output.empty? ? nil : output
      end
    end
  end
end