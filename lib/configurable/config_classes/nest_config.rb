module Configurable
  module ConfigClasses
    
    # Represents a config where the input is expected to be Configurable.
    class NestConfig < SingleConfig
      
      def initialize(key, attrs={})
        attrs[:type] ||= NestType.new(attrs)
        super
      end
      
      def configurable
        @default
      end
      
      def default
        configurable.config.to_hash
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
        unless value.kind_of?(configurable.class)
          value = default.merge(value)
          value = type.cast(value)
        end
        
        receiver.send(writer, value)
      end
      
      def cast(input)
        configurable.class.configs.import(input)
      end
      
      def uncast(value)
        configurable.class.configs.export(value)
      end
      
      protected
      
      def check_default(default) # :nodoc:
        unless default.respond_to?(:config) && default.class.respond_to?(:configs)
          raise ArgumentError, "invalid default: #{default.inspect} (not a Configurable)"
        end
        super
      end
    end
  end
end