module Configurable
  module Configs
    
    # Represents a config where the input is expected to be Configurable.
    class Nest < Config
    
      # Initializes a new NestConfig
      def initialize(key, attrs={})
        super
        
        unless configurable_class.kind_of?(Class) && configurable_class.ancestors.include?(Configurable)
          raise ArgumentError, "not a Configurable class: #{configurable_class}"
        end
      end
    
      # The nested configurable class
      def configurable_class
        @default
      end
    
      # Returns a hash of the default configuration values for
      # configurable_class.
      def default
        default = {}
        configurable_class.configs.each_pair do |key, config|
          default[key] = config.default
        end
        default
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
          configurable = receiver.send(reader) || receiver.send(writer, configurable_class.new)
          configurable.config.merge!(value)
        end
      end
      
      # Same as super, but recursively maps the result using configurable_class.
      def map_by_key(source, target={})
        if source.has_key?(name)
          target[key] = configurable_class.map_by_key(source[name])
        end
        
        target
      end
      
      # Same as super, but recursively maps the result using configurable_class
      def map_by_name(source, target={})
        if source.has_key?(key)
          target[name] = configurable_class.map_by_name(source[key])
        end
        
        target
      end
      
      def cast(value)
        value = super(value)
        configurable_class.cast(value)
      end
      
      def traverse(nesting=[], &block)
        nesting.push key
        configurable_class.configs.each_value do |config|
          config.traverse(nesting, &block)
        end
        nesting.pop
        self
      end
    
      # Returns an inspection string.
      def inspect
        "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} configurable_class=#{configurable_class.inspect} >"
      end
    end
  end
end