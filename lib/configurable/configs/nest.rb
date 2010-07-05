require 'configurable/config'

module Configurable
  module Configs
    class Nest < Config
      
      # Initializes a new NestConfig
      def initialize(name, configurable_class=nil, options={})
        unless configurable_class.kind_of?(Class) && configurable_class.ancestors.include?(Configurable)
          raise ArgumentError, "not a Configurable class: #{configurable_class}"
        end
        
        super 
      end
      
      # The nested configurable class
      def configurable_class
        @default
      end
      
      # Returns a hash of the default configuration values for configurable_class.
      def default
        default = {}
        configurable_class.configurations.each_pair do |key, config|
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
      
      def define_writer(receiver_class)
        line = __LINE__ + 1
        receiver_class.class_eval %Q{
          def #{name}=(value)
            value = #{caster}(value)
            
            unless value.kind_of?(#{configurable_class})
              raise ArgumentError, "invalid value for #{name}: \#{value.inspect}"
            end
            
            @#{name} = value
          end
          public :#{name}=
        }, __FILE__, line
      end
    
      # Returns an inspection string.
      def inspect
        "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} configurable_class=#{configurable_class.inspect} >"
      end
    end
  end
end