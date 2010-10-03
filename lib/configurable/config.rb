module Configurable
  
  # Configs are used by ConfigHash to delegate get/set configs on a receiver.
  # Config instances typically do not do any work themselves; the receiver
  # class is responsible for defining the actual reader/writer methods so that
  # their logic will be enforced when config values are accessed directly
  # rather than through Config.
  #
  # However, in most cases the Config really knows what the reader/writer
  # methods should look like.  As a result they have the rather odd ability to
  # define the default reader/writer methods on a reciever class. Use as
  # appropriate.
  class Config
    
    # The config name
    attr_reader :name
    
    # The reader method called on a receiver during get
    attr_reader :reader
    
    # The writer method called on a receiver during set
    attr_reader :writer
    
    attr_reader :caster
    
    # The default config value
    attr_reader :default
    
    # A hash of attributes used to format self in user interfaces.  Typically
    # these are just the attributes used by ConfigParser (ex: long, short,
    # desc).
    attr_reader :attrs
    
    # Initializes a new Config.
    def initialize(name, default=nil, reader=nil, writer=nil, caster=nil, attrs={})
      check_name(name)
      
      @name    = name
      @default = default
      @reader  = (reader || name).to_sym
      @writer  = (writer || "#{name}=").to_sym
      @caster  = caster
      @attrs   = attrs
    end
    
    # Get the specified attribute from attrs.
    def [](key)
      attrs[key]
    end
    
    # Calls reader on the receiver and returns the result.
    def get(receiver)
      receiver.send(reader)
    end
    
    # Calls writer on the receiver with the value.
    def set(receiver, value)
      receiver.send(writer, value)
    end
    
    def cast(value)
      caster ? caster.call(value) : value
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