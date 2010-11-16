module Configurable
  module ConfigTypes
    class NestType < ObjectType
      matches Configurable
      
      attr_reader :default
      
      def initialize(attrs={})
        @default = attrs[:default]
        
        unless default.kind_of?(Configurable)
          raise ArgumentError, "not a configurable class: #{default.inspect}"
        end
        
        super
      end
      
      def cast(input)
        configurable = default.dup
        configs = configurable.class.configs.import(input)
        
        configurable.config.merge!(configs)
        configurable
      end
      
      def uncast(value)
        configs = value.config.to_hash
        default.class.configs.export(configs)
      end
    end
  end
end