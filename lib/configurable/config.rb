module Configurable
  
  # Configs setup config getters/setters, determine how to delegate read/write
  # operations to a receiver, and track metadata for presentation of configs
  # in various user contexts.
  class Config
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
    
    # Initializes a new Config.
    def initialize(name, default=nil, options={})
      check_name(name)
      
      @name    = name
      @reader  = (options[:reader] || name).to_sym
      @writer  = (options[:writer] || "#{name}=").to_sym
      @desc    = options[:desc]
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
    
    def define_reader(receiver_class)
      line = __LINE__ + 1
      receiver_class.class_eval %Q{
        attr_reader :#{name}
        public :#{name}
      }, __FILE__, line
    end
    
    def define_writer(receiver_class, caster=nil)
      line = __LINE__ + 1
      receiver_class.class_eval %Q{
        def #{name}=(value)
          @#{name} = #{caster}(value)
        end
        public :#{name}=
      }, __FILE__, line
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