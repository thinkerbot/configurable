module Configurable
  module ConfigTypes
    class NestType < ObjectType
      matches Configurable
      
      attr_reader :configurable_class
      
      def initialize(attrs={})
        @configurable_class = attrs[:configurable_class]
        
        unless configurable_class.respond_to?(:configs)
          raise ArgumentError, "not a configurable class: #{configurable_class.inspect}"
        end
        
        super
      end
      
      def cast(input)
        configurable_class.configs.import(input)
      end
      
      def uncast(value)
        configurable_class.configs.export(value)
      end
    end
  end
end