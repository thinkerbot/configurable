require 'configurable/config'

module Configurable
  
  # NestConfigs are used to nest configurable classes.
  class NestConfig < Config
    
    # The nested configurable class
    attr_reader :nest_class
    
    # Initializes a new NestConfig
    def initialize(nest_class, reader, writer="#{reader}=", init=true, attributes={})
      self.nest_class = nest_class
      self.reader = reader
      self.writer = writer
      
      @init = init
      @attributes = attributes
    end
    
    # Returns a hash of the default configuration values for nest_class.
    def default
      default = {}
      nest_class.configurations.each_pair do |key, delegate|
        default[key] = delegate.default
      end
      default
    end
    
    # Calls the reader on the reciever to retreive an instance of the 
    # nest_class and returns it's config.  Returns nil if the reader
    # returns nil.
    def get(receiver)
      if instance = receiver.send(reader)
        instance.config
      else
        nil
      end
    end
    
    # Calls the reader on the reciever to retrieve an instance of the
    # nest_class, and reconfigures it with value.  The instance will
    # be initialized by init if necessary.
    #
    # If value is an instance of the nest_class, then it will be set
    # by calling writer.
    def set(receiver, value)
      if value.kind_of?(nest_class)
        receiver.send(writer, value)
      else
        configurable = receiver.send(reader) || init(receiver)
        configurable.reconfigure(value)
      end
    end
    
    # Initializes an instance of nest_class and sets it on the receiver.  The
    # instance is initialized by calling nest_class.new with no arguments.
    def init(receiver)
      receiver.send(writer, nest_class.new)
    end
    
    # Returns an inspection string.
    def inspect
      "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} nest_class=#{nest_class.inspect} >"
    end
    
    protected
    
    # sets nest_class, checking that the nested class
    # is both a Class and Configurable
    def nest_class=(nest_class) # :nodoc:
      unless nest_class.kind_of?(Class) && nest_class.ancestors.include?(Configurable)
        raise ArgumentError, "not a Configurable class: #{nest_class}"
      end
      
      @nest_class = nest_class
    end
  end
end