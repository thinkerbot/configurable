module Configurable
  
  # Configs are used by ConfigHash to determine how to delegate read/write
  # operations to a receiver.  Configs also track metadata related to their
  # presentation in various contexts.
  class Config
    # The reader method called on a receiver during get
    attr_reader :reader

    # The writer method called on a receiver during set
    attr_reader :writer
    
    # An hash of metadata for self
    attr_reader :attributes

    # Initializes a new Config.
    def initialize(reader, writer="#{reader}=", default=nil, attributes={}, init=true, duplicate=false)
      self.reader = reader
      self.writer = writer
      @default = default
      @attributes = attributes
      @init = init
      @duplicate = duplicate
      @duplicate = :dup if @duplicate == true
    end
    
    # Returns the default value.  If duplicate is specified and the default
    # may be duplicated (see Config.duplicable_value?) then a duplicate
    # of the default is returned.
    def default(duplicate=true)
      @duplicate && duplicate ? @default.send(@duplicate) : @default
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
    
    # Returns true or false as specified in new.  True indicates that this
    # delegate is allowed to initialize values on the receiver during
    # Configurable#initialize_config.
    def init?
      @init
    end
    
    # Returns true or false as specified in new.  True indicates that the
    # default value is duplicatd for each configurable instance.
    def duplicate?
      @duplicate ? true : false
    end
    
    # Returns an inspection string.
    def inspect
      "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} default=#{default.inspect} >"
    end
    
    protected
    
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