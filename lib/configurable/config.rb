module Configurable
  
  # Configs setup config getters/setters, determine how to delegate read/write
  # operations to a receiver, and track metadata for presentation of configs
  # in various user contexts.
  class Config
    class << self
      attr_accessor :options
      attr_accessor :pattern
    end
    @options = {}
    @pattern = nil
    
    # The config name
    attr_reader :name
    
    # The reader method called on a receiver during get
    attr_reader :reader
    
    # The writer method called on a receiver during set
    attr_reader :writer
    
    # The default config value
    attr_reader :default
    
    # A description of the config
    attr_reader :desc
    
    attr_reader :cast_method_name
    
    # Initializes a new Config.
    def initialize(name, default=nil, options={})
      check_name(name)
      
      @name    = name
      @reader  = (options[:reader] || name).to_sym
      @writer  = (options[:writer] || "#{name}=").to_sym
      @desc    = options[:desc]
      @default = default
      @cast_method_name = (options[:cast_method_name] || "cast_#{name}")
    end
    
    # Calls reader on the receiver and returns the result.
    def get(receiver)
      receiver.send(reader)
    end
    
    # Calls writer on the receiver with the value.
    def set(receiver, value)
      receiver.send(writer, value)
    end
    
    def define_on(receiver_class, method_name=cast_method_name)
      line = __LINE__ + 1
      receiver_class.class_eval %Q{
        def #{method_name}(input)
          input
        end
        private :#{method_name}
      }, __FILE__, line
      
      method_name
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