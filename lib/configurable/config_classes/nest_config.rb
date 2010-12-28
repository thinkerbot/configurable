module Configurable
  module ConfigClasses
    
    # Represents a config where the input is expected to be Configurable.
    class NestConfig < ScalarConfig
      
      def initialize(key, attrs={})
        unless attrs.has_key?(:default)
          attrs[:default] = {}
        end
        
        unless attrs.has_key?(:type)
          attrs[:type] = NestType.new(attrs)
        end
        
        super
        
        unless type.respond_to?(:init)
          raise "invalid type for #{self}: #{type.inspect}"
        end
      end
      
      # Calls the reader on the reciever to retreive an instance of the
      # configurable_class and returns it's config.  Returns nil if the reader
      # returns nil.
      def get(receiver)
        if configurable = receiver.send(reader)
          configurable.config
        else
          nil
        end
      end
  
      # Calls the reader on the reciever to retrieve an instance of the
      # configurable_class, and reconfigures it with value.  The instance will
      # be initialized by init if necessary.
      #
      # If value is an instance of the configurable_class, then it will be set
      # by calling writer.
      def set(receiver, value)
        unless value.respond_to?(:config)
          value = default.merge(value)
          value = type.init(value)
        end
        
        receiver.send(writer, value)
      end
    end
  end
end