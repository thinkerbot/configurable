module Configurable
  module ConfigClasses
    
    # Represents a config where the input is expected to be Configurable.
    class Nest < Config
      
      def configurable_class
        default.class
      end
      
      def configs
        configurable_class.configs
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
        if value.kind_of?(configurable_class)
          receiver.send(writer, value)
        else
          configurable = receiver.send(reader) || receiver.send(writer, default.dup)
          configurable.config.merge!(value) # requires value.each_pair
        end
      end
      
      def cast(input)
        configs.import(super(input))
      end
      
      def uncast(value)
        super(configs.export(value))
      end
      
      # Returns an inspection string.
      def inspect
        "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} configurable_class=#{configurable_class.to_s} >"
      end
      
      protected
      
      def check_default(default) # :nodoc:
        unless default.class.respond_to?(:configs) && default.respond_to?(:config)
          raise ArgumentError, "invalid default: #{default.inspect} (not a Configurable)"
        end
        super
      end
    end
  end
end