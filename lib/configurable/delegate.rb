module Configurable
  
  # Delegates are used by DelegateHash to determine how to delegate read/write
  # operations to a receiver.  Delegates are the mechanism through which
  # configurations are managed and track metadata related to the presentation
  # of configurations in various contexts.
  class Delegate
    class << self
      
      # Determines if the value is duplicable.  Non-duplicable values 
      # include nil, true, false, Symbol, Numeric, Method, Module, and 
      # any object that does not respond to dup.
      def duplicable_value?(value)
        case value
        when nil, true, false, Symbol, Numeric, Method, Module then false
        else value.respond_to?(:dup)
        end
      end
    end
      
    # The reader method called on a receiver during get
    attr_reader :reader

    # The writer method called on a receiver during set
    attr_reader :writer
    
    # An hash of metadata for self, often used to indicate how a delegate is
    # presented in different contexts (ex on the command line, in a web form,
    # or a desktop app).
    attr_reader :attributes

    # Initializes a new Delegate.
    def initialize(reader, writer="#{reader}=", default=nil, init=true, attributes={})
      self.reader = reader
      self.writer = writer
      self.default = default
      
      @init = init
      @attributes = attributes
    end
    
    # Returns the default value.  If duplicate is specified and the default
    # may be duplicated (see Delegate.duplicable_value?) then a duplicate
    # of the default is returned.
    def default(duplicate=true)
      duplicate && @duplicable ? @default.dup : @default
    end
    
    # Returns the value for the specified attribute, or default if the
    # attribute is unspecified.
    def [](key, default=nil)
      attributes.has_key?(key) ? attributes[key] : default
    end
    
    # Calls reader on the receiver and returns the result.
    def get(receiver)
      receiver.send(reader)
    end
    
    # Calls writer on the receiver with the value.
    def set(receiver, value)
      receiver.send(writer, value)
    end
    
    # Sets the default value on the receiver.  Normally this method is only
    # called by a Configurable during initialize_config, and only if init?
    # returns true.
    def init(receiver)
      receiver.send(writer, default)
    end
    
    # Returns true or false as specified in new.  True indicates that this
    # delegate is allowed to initialize values on the receiver during
    # Configurable#initialize_config.
    def init?
      @init
    end
    
    # Returns an inspection string.
    def inspect
      "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} default=#{default.inspect} >"
    end
    
    protected
    
    # Sets the default and updates the @duplicable flag.  If this method is
    # overridden or never called, @duplicable is not set and the default
    # reader may also have to be overridden.
    def default=(value) # :nodoc:
      @default = value
      @duplicable = Delegate.duplicable_value?(value)
    end
    
    # Sets the reader for self, assuring the reader is not nil.
    def reader=(value) # :nodoc:
      raise ArgumentError, "reader may not be nil" if value.nil?
      @reader = value.to_sym
    end

    # Sets the writer for self, assuring the writer is not nil.
    def writer=(value) # :nodoc:
      raise ArgumentError, "writer may not be nil" if value.nil?
      @writer = value.to_sym
    end
  end
end