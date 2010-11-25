module Configurable
  module ConfigTypes
    class NestType < ObjectType
      class << self
        def init(&block)
          define_method(:init, &block) if block
          self
        end
      end
      matches Hash
      
      attr_reader :configurable
      
      def initialize(attrs={})
        @configurable = attrs[:configurable]
        
        unless configurable.respond_to?(:config) && configurable.class.respond_to?(:configs)
          raise ArgumentError, "invalid configurable: #{configurable.inspect}"
        end
        
        super
      end
      
      def init(input)
        obj = configurable.dup
        obj.config.merge!(input)
        obj
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