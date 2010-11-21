module Configurable
  module ConfigTypes
    class NestType < ObjectType
      matches Configurable
      
      attr_reader :configurable
      
      def initialize(attrs={})
        @configurable = attrs[:default]
        
        unless configurable.kind_of?(Configurable)
          raise ArgumentError, "not a Configurable: #{configurable.inspect}"
        end
        
        super
      end
      
      def cast(input)
        configurable.class.configs.import(input)
      end
      
      def uncast(value)
        configurable.class.configs.export(value)
      end
    end
  end
end