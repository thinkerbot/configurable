module Configurable
  
  # Delegates are used by DelegateHash to determine how to map read/write
  # operations to a receiver.
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
      
    # The reader method, by default key
    attr_reader :reader

    # The writer method, by default key=
    attr_reader :writer
    
    # An hash of metadata for self, used to present the delegate in different
    # contexts (ex on the command line, in a web form, or a desktop app).
    # Note that attributes should be set through []= and not through this
    # reader.
    attr_reader :attributes

    # Initializes a new Delegate with the specified key and default value.
    def initialize(reader, writer="#{reader}=", default=nil, init=true, attributes={})
      self.reader = reader
      self.writer = writer
      self.default = default
      
      @init = init
      @attributes = attributes
    end
    
    def default
       @duplicable ? @default.dup : @default
    end
    
    # Returns the value for the specified attribute, or
    # default, if the attribute is unspecified.
    def [](key, default=nil)
      attributes.has_key?(key) ? attributes[key] : default
    end
    
    def get(receiver)
      receiver.send(reader)
    end
    
    def set(receiver, value)
      receiver.send(writer, value)
    end
    
    def init(receiver)
      receiver.send(writer, default)
    end
    
    def init?
      @init
    end
    
    def inspect
      "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} default=#{default.inspect} >"
    end
    
    protected
    
    def default=(value)
      @default = value
      @duplicable = Delegate.duplicable_value?(value)
    end
    
    # Sets the reader for self.
    def reader=(value)
      raise ArgumentError, "reader may not be nil" if value == nil
      @reader = value.to_sym
    end

    # Sets the writer for self.
    def writer=(value)
      raise ArgumentError, "writer may not be nil" if value == nil
      @writer = value.to_sym
    end
  end
end