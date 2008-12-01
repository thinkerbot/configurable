module Configurable
  
  # Configs are used by ConfigHash to determine how to map read/write
  # operations to a receiver.
  class Config
    class << self
    
      # Determines if the value is duplicable.  Non-duplicable 
      # values include nil, true, false, Symbol, Numeric, and 
      # any object that does not respond to dup.
      def duplicable_value?(value)
        case value
        when nil, true, false, Symbol, Numeric, Method then false
        else value.respond_to?(:dup)
        end
      end
    end
    
    attr_accessor :key

    # The reader method, by default key
    attr_reader :reader
  
    # The writer method, by default key=
    attr_reader :writer
  
    # An array of metadata for self, used to present the 
    # delegate in different contexts (ex on the command
    # line or web).
    attr_reader :attributes
    
    # Initializes a new Config with the specified key 
    # and default value.
    def initialize(key, default=nil, reader=key, writer="#{reader}=", attributes={})
      self.default = default
      self.reader = reader
      self.writer = writer
      
      @key = key
      @attributes = attributes
    end

    # Sets the default value for self.
    def default=(value)
      @duplicable = Config.duplicable_value?(value)
      @default = value.freeze
    end
  
    # Returns the default value, or a duplicate of the default
    # value if specified and the default value is duplicable
    # (see Config.duplicable_value?)
    def default(duplicate=true)
      duplicate && @duplicable ? @default.dup : @default
    end
  
    # Sets the reader for self.  The reader is symbolized,
    # but may also be set to nil.
    def reader=(value)
      @reader = value == nil ? value : value.to_sym
    end
  
    # Sets the writer for self.  The writer is symbolized,
    # but may also be set to nil.
    def writer=(value)
      @writer = value == nil ? value : value.to_sym
    end
  
    # True if another is a kind of Config with the same
    # reader, writer, and default value.  Attributes are
    # not considered.
    def ==(another)
      another.kind_of?(Config) &&
      self.key == another.key &&
      self.reader == another.reader &&
      self.writer == another.writer &&
      self.default(false) == another.default(false)
    end
  end
end