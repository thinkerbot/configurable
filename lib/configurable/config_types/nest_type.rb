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
        configs = value.config.to_hash
        configurable.class.configs.export(configs)
      end
    end
  end
end