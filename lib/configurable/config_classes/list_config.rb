module Configurable
  module ConfigClasses
    class ListConfig < ScalarConfig
      
      def initialize(key, attrs={})
        unless attrs.has_key?(:default)
          attrs[:default] = []
        end
        
        super
      end
      
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