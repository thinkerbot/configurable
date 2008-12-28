module Configurable
  
  # Delegates are used by DelegateHash to determine how to map read/write
  # operations to a receiver.
  class Delegate
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

    # The reader method, by default key
    attr_reader :reader

    # The writer method, by default key=
    attr_reader :writer

    # An hash of metadata for self, used to present the 
    # delegate in different contexts (ex on the command
    # line, in a web form, or a desktop app).
    attr_reader :attributes

    # Initializes a new Delegate with the specified key 
    # and default value.
    def initialize(reader, writer="#{reader}=", default=nil, attributes={})
      self.default = default
      self.reader = reader
      self.writer = writer
  
      @attributes = attributes
    end
    
    # Returns the value for the specified attribute, or
    # default, if the attribute is unspecified.
    def [](key, default=nil)
      attributes.has_key?(key) ? attributes[key] : default
    end

    # Sets the default value for self.
    def default=(value)
      @duplicable = Delegate.duplicable_value?(value)
      @default = value.freeze
    end

    # Returns the default value, or a duplicate of the default
    # value if specified and the default value is duplicable
    # (see Delegate.duplicable_value?)
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
    
    # Returns true if the default value is a kind of DelegateHash.
    def is_nest?
      @default.kind_of?(DelegateHash)
    end

    # True if another is a kind of Delegate with the same
    # reader, writer, and default value.  Attributes are
    # not considered.
    def ==(another)
      another.kind_of?(Delegate) &&
      self.reader == another.reader &&
      self.writer == another.writer &&
      self.default(false) == another.default(false)
    end
  end
end