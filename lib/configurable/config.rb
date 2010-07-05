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
    
    attr_reader :options_const_name
    
    attr_reader :caster
    
    # Initializes a new Config.
    def initialize(name, default=nil, options={})
      check_name(name)
      
      @name    = name
      @reader  = (options[:reader] || name).to_sym
      @writer  = (options[:writer] || "#{name}=").to_sym
      @caster  = (options[:caster] || "cast_#{name}")
      @desc    = options[:desc]
      @default = default
      @options_const_name = options[:options_const_name]
    end
    
    # Calls reader on the receiver and returns the result.
    def get(receiver)
      receiver.send(reader)
    end
    
    # Calls writer on the receiver with the value.
    def set(receiver, value)
      receiver.send(writer, value)
    end
    
    def select?
      !options_const_name.nil?
    end
    
    def list?
      Array === default
    end
    
    def define_caster(receiver_class)
      line = __LINE__ + 1
      receiver_class.class_eval %Q{
        def #{caster}(input)
          input
        end
        private :#{caster}
      }, __FILE__, line
    end
    
    def define_reader(receiver_class)
      line = __LINE__ + 1
      receiver_class.class_eval %Q{
        attr_reader :#{name}
        public :#{name}
      }, __FILE__, line
    end
    
    def define_writer(receiver_class)
      if list?
        if select?
          define_list_select_writer(receiver_class)
        else
          define_list_writer(receiver_class)
        end
      else
        if select?
          define_select_writer(receiver_class)
        else
          define_basic_writer(receiver_class)
        end
      end
      define_caster(receiver_class)
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

    def define_basic_writer(receiver_class)
      line = __LINE__ + 1
      receiver_class.class_eval %Q{
        def #{name}=(input)
          @#{name} = #{caster}(input)
        end
        public :#{name}=
      }, __FILE__, line
    end
    
    def define_list_writer(receiver_class)
       line = __LINE__ + 1
       receiver_class.class_eval %Q{
         def #{name}=(values)
           unless values.kind_of?(Array)
             raise ArgumentError, "invalid value for #{name}: \#{values.inspect}"
           end

           values.collect! {|value| #{caster}(value) }
           @#{name} = values
         end
         public :#{name}=
       }, __FILE__, line
     end

     def define_select_writer(receiver_class)
       line = __LINE__ + 1
       receiver_class.class_eval %Q{
         def #{name}=(value)
           value = #{caster}(value)
           unless #{options_const_name}.include?(value)
             raise ArgumentError, "invalid value for #{name}: \#{value.inspect}"
           end
           @#{name} = value
         end
         public :#{name}=
       }, __FILE__, line
     end

     def define_list_select_writer(receiver_class)
       line = __LINE__ + 1
       receiver_class.class_eval %Q{
         def #{name}=(values)
           unless values.kind_of?(Array)
             raise ArgumentError, "invalid value for #{name}: \#{values.inspect}"
           end

           values.collect! {|value| #{caster}(value) }

           unless values.all? {|value| #{options_const_name}.include?(value) }
             raise ArgumentError, "invalid values for #{name}: \#{values.inspect}"
           end

           @#{name} = values
         end
         public :#{name}=
       }, __FILE__, line
     end
  end
end