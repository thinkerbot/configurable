module Configurable
  module ConfigClasses
    
    # Represents a config where the input is expected to be Configurable.
    class Nest < Config
    
      # Initializes a new NestConfig
      def initialize(key, attrs={})
        super
        
        unless configurable_class.respond_to?(:configs)
          raise ArgumentError, "not a Configurable class: #{configurable_class}"
        end
      end
    
      # The nested configurable class.
      def configurable_class
        @default
      end
      
      # Returns the configs for the configurable class.
      def configs
        @default.configs
      end
    
      # Returns a hash of the default config values for configurable_class.
      def default
        configs.to_default
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
      
      # Same as super but returns value (not value.to_s) if no uncaster is
      # specified.
      def uncast(value)
        uncaster ? uncaster.call(value) : value
      end
      
      # Same as super, but imports the casted value using configs.
      def import(source, target={}, &block)
        super do |config, value|
          value = configs.import(value, &block)
          value = yield(self, value) if block
          value
        end
      end
      
      # Same as super, but exports the source value using configs before
      # uncast.
      def export(source, target={}, &block)
        super do |config, value|
          value = configs.export(value, &block)
          value = yield(self, value) if block
          value
        end
      end
      
      # Yields each config in configs to the block with nesting, after appened
      # self to nesting.
      def traverse(nesting=[], &block)
        nesting.push self
        configs.each_value do |config|
          config.traverse(nesting, &block)
        end
        nesting.pop
        self
      end
    
      # Returns an inspection string.
      def inspect
        "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} configurable_class=#{configurable_class.to_s} >"
      end
    end
  end
end