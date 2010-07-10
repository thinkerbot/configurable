module Configurable
  
  # Configs setup config getters/setters, determine how to delegate read/write
  # operations to a receiver, and track metadata for presentation of configs
  # in various user contexts.
  class Config
    class << self
      attr_reader :matcher
      
      protected
      
      def match(pattern)
        @matcher = pattern
      end
    end
    match nil
    
    # The config name
    attr_reader :name
    
    # The reader method called on a receiver during get
    attr_reader :reader
    
    # The writer method called on a receiver during set
    attr_reader :writer
    
    # The default config value
    attr_reader :default
    
    attr_reader :options
    
    # A description of the config
    attr_reader :desc
    
    attr_reader :long
    
    attr_reader :short
    
    # Initializes a new Config.
    def initialize(name, default=nil, opts={})
      check_name(name)
      
      @name    = name
      @reader  = (opts[:reader] || name).to_sym
      @writer  = (opts[:writer] || "#{name}=").to_sym
      @options = opts[:options]
      @desc    = opts[:desc]
      @long    = opts[:long] || name
      @short   = opts[:short]
      @default = default
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
      !options.nil?
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