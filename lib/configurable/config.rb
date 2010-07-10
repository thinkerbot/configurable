module Configurable
  
  # Configs setup config getters/setters, determine how to delegate read/write
  # operations to a receiver, and track metadata for presentation of configs
  # in various user contexts.
  class Config
    class << self
      attr_reader :caster
      attr_reader :matcher
      
      protected
      
      def cast_with(method_name)
        @caster = method_name
      end
      
      def match(pattern)
        @matcher = pattern
      end
    end
    cast_with nil
    match nil
    
    # The config name
    attr_reader :name
    
    # The reader method called on a receiver during get
    attr_reader :reader
    
    # The writer method called on a receiver during set
    attr_reader :writer
    
    # The default config value
    attr_reader :default
    
    attr_reader :attributes
    
    # Initializes a new Config.
    def initialize(name, default=nil, reader=nil, writer=nil, attributes={})
      check_name(name)
      
      @name    = name
      @default = default
      @reader  = (reader || name).to_sym
      @writer  = (writer || "#{name}=").to_sym
      @attributes = attributes
    end
    
    def [](key)
      attributes[key]
    end
    
    # Calls reader on the receiver and returns the result.
    def get(receiver)
      receiver.send(reader)
    end
    
    # Calls writer on the receiver with the value.
    def set(receiver, value)
      receiver.send(writer, value)
    end
    
    def list?
      Array === default
    end
    
    def select?
      attributes[:options] ? true : false
    end
    
    # Returns an inspect string.
    def inspect
      "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} default=#{default.inspect} >"
    end
    
    protected
    
    def check_name(name) # :nodoc
      unless name.kind_of?(Symbol)
        raise "invalid name: #{name.inspect} (not a Symbol)"
      end

      unless name.to_s =~ /\A\w+\z/
        raise NameError.new("invalid characters in name: #{name.inspect}")
      end
    end
  end
end