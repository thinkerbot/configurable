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
    
    def nil_value
      attributes[:nil_value]
    end
    
    def options
      attributes[:options]
    end
    
    def ivar
      @ivar ||= "@#{name}".to_sym
    end
    
    def define_reader(receiver_class)
      line = __LINE__ + 1
      receiver_class.class_eval %Q{
        attr_reader :#{name}
        public :#{name}
      }, __FILE__, line
    end
    
    def define_writer(receiver_class)
      caster = get_caster(receiver_class)
      options = self.options
      ivar = self.ivar
      name = self.name
      nil_value = self.nil_value
      
      receiver_class.send(:define_method, writer) do |value|
        value = nil_value if value.nil?
        value = send(caster, value) if caster
        
        unless options.nil? || options.include?(value)
          raise ArgumentError, "invalid value for #{name}: #{value.inspect}"
        end
        
        instance_variable_set(ivar, value)
      end
    end
    
    # Returns an inspect string.
    def inspect
      "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} default=#{default.inspect} >"
    end
    
    protected
    
    def get_caster(receiver_class)
      type = attributes[:type]
      config_type = receiver_class.config_types[type]
      config_type ? config_type.caster : nil
    end
    
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