module Configurable
  
  # Configs are used by ConfigHash to delegate get/set configs on a receiver.
  # They also track metadata for displaying configs in user interfaces, and a
  # caster for casting configs from user inputs (normally strings) to the
  # expected config type.
  class Config
    
    # The config key, used as a hash key for access.
    attr_reader :key
    
    # The config name, used where an arbitrary key is not appropriate (ex: in
    # user interfaces, and when defining the default reader/writer). Valid
    # names are strings consisting of word characters.
    attr_reader :name
    
    # The reader method called on a receiver during get.
    attr_reader :reader
    
    # The writer method called on a receiver during set.
    attr_reader :writer
    
    # The caster, which must respond to call or be nil.
    attr_reader :caster
    
    # The default config value.
    attr_reader :default
    
    # A hash of any other attributes (typically attributes like long and short
    # used to format self in user interfaces).
    attr_reader :attrs
    
    # Initializes a new Config.
    def initialize(key, attrs={})
      @key     = key
      @name    = attrs[:name] || @key.to_s
      check_name(@name)
      
      @default = attrs[:default]
      @reader  = (attrs[:reader] ||= name).to_sym
      @writer  = (attrs[:writer] ||= "#{name}=").to_sym
      @caster  = attrs[:caster]
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
    
    # Calls the caster with value and returns the result. Returns the value if
    # no caster is set.
    def cast(value)
      caster ? caster.call(value) : value
    end
    
    # Writes the value keyed by name in source into target by key.
    def extract(source, target={})
      target[key] = source[name] if source.has_key?(name)
      target
    end
    
    # Returns an inspect string.
    def inspect
      "#<#{self.class}:#{object_id} key=#{key} name=#{name} default=#{default.inspect} reader=#{reader} writer=#{writer} >"
    end
    
    protected
    
    def check_name(name) # :nodoc
      unless name.kind_of?(String)
        raise "invalid name: #{name.inspect} (not a String)"
      end

      unless name =~ /\A\w+\z/
        raise NameError.new("invalid characters in name: #{name.inspect}")
      end
    end
  end
end