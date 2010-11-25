module Configurable
  module ConfigTypes
    class NestType < ObjectType
      matches Configurable
      
      attr_reader :configurable
      
      def initialize(attrs={})
        @configurable = attrs[:default]
        
        # unless configurable.kind_of?(Configurable)
        #   raise ArgumentError, "not a Configurable: #{configurable.inspect}"
        # end
        
        super
      end
      
      def cast(input)
        obj = configurable.dup
        obj.merge!(input)
        obj
      end
      
      def uncast(value)
        value.config.to_hash
      end
    end
  end
end