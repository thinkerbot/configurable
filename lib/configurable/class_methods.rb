require 'lazydoc/attributes'
require 'configurable/delegate_hash'
require 'configurable/indifferent_access'
require 'configurable/validation'

autoload(:ConfigParser, 'config_parser')

module Configurable
  
  # ClassMethods extends classes that include Configurable and
  # provides methods for declaring configurations.
  module ClassMethods
    include Lazydoc::Attributes

    # A hash of (key, Delegate) pairs defining the class configurations.
    attr_reader :configurations

    def self.extended(base) # :nodoc:
      unless base.instance_variable_defined?(:@source_file)
        caller[2] =~ Lazydoc::CALLER_REGEXP
        base.instance_variable_set(:@source_file, File.expand_path($1)) 
      end
      
      base.send(:initialize_configurations).extend(IndifferentAccess)
    end

    def inherited(child) # :nodoc:
      unless child.instance_variable_defined?(:@source_file)
        caller[0] =~ Lazydoc::CALLER_REGEXP
        child.instance_variable_set(:@source_file, File.expand_path($1)) 
      end

      # deep duplicate configurations
      unless child.instance_variable_defined?(:@configurations)
        duplicate = child.instance_variable_set(:@configurations, configurations.dup)
        duplicate.each_pair {|key, config| duplicate[key] = config.dup }
        duplicate.extend(IndifferentAccess) if configurations.kind_of?(IndifferentAccess)
      end
      super
    end
    
    # Parses configurations from argv in a non-destructive manner by generating
    # a ConfigParser using the configurations for self.  Parsed configs are 
    # added to config (note that you must keep a separate reference to 
    # config as it is not returned by parse).  The parser will is yielded to the
    # block, if given, to register additonal options.  Returns an array of the 
    # arguments that remain after parsing.
    #
    # See ConfigParser#parse for more information.
    def parse(argv=ARGV, config={})
      ConfigParser.new do |parser|
        parser.add(configurations)
        yield(parser) if block_given?
      end.parse(argv, config)
    end
    
    # Same as parse, but removes parsed args from argv.
    def parse!(argv=ARGV, config={})
      argv.replace(parse(argv, config))
    end
    
    protected
    
    # Sets configurations to symbolize keys for AGET ([]) and ASET([]=)
    # operations, or not.  By default, configurations will use
    # indifferent access.
    def use_indifferent_access(input=true)
      if input
        @configurations.extend(IndifferentAccess)
      else
        @configurations = configurations.dup
      end
    end

    # Declares a class configuration and generates the associated accessors. 
    # If a block is given, the <tt>key=</tt> method will set <tt>@key</tt> 
    # to the return of the block, which executes in class-context.  
    #
    #   class SampleClass
    #     include Configurable
    #
    #     config :str, 'value'
    #     config(:upcase, 'value') {|input| input.upcase } 
    #   end
    #
    #   # An equivalent class to illustrate class-context
    #   class EquivalentClass
    #     attr_accessor :str
    #     attr_reader :upcase
    #
    #     UPCASE_BLOCK = lambda {|input| input.upcase }
    #
    #     def upcase=(input)
    #       @upcase = UPCASE_BLOCK.call(input)
    #     end
    #   end
    #
    def config(key, value=nil, attributes={}, &block)
      attributes = default_attributes(block).merge!(attributes)
      
      # register with Lazydoc
      attributes[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      
      if block_given?
        instance_variable = "@#{key}".to_sym
        config_attr(key, value, attributes) do |input|
          instance_variable_set(instance_variable, yield(input))
        end
      else
        config_attr(key, value, attributes)
      end
    end

    # Declares a class configuration and generates the associated accessors. 
    # If a block is given, the <tt>key=</tt> method will perform the block
    # with instance-context.
    #
    #   class SampleClass
    #     include Configurable
    #
    #     def initialize
    #       initialize_config
    #     end
    #
    #     config_attr :str, 'value'
    #     config_attr(:upcase, 'value') {|input| @upcase = input.upcase } 
    #   end
    #
    #   # An equivalent class to illustrate instance-context
    #   class EquivalentClass
    #     attr_accessor :str
    #     attr_reader :upcase
    #
    #     def upcase=(input)
    #       @upcase = input.upcase
    #     end
    #   end
    #
    def config_attr(key, value=nil, attributes={}, &block)
      attributes = default_attributes(block).merge!(attributes)
      
      # register with Lazydoc
      attributes[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      
      # define the default public reader method
      reader = attributes.delete(:reader)

      case reader
      when true
        reader = key
        attr_reader(key) 
        public(key)
      when false
        reader = key
      end

      # define the default public writer method
      writer = attributes.delete(:writer)

      if block_given? && writer != true
        raise ArgumentError, "a block may not be specified without writer == true"
      end

      case writer
      when true
        writer = "#{key}="
        block_given? ? define_method(writer, &block) : attr_writer(key)
        public writer
      when false
        writer = "#{key}="
      end
  
      configurations[key] = Delegate.new(reader, writer, value, attributes)
    end

    # Adds a configuration to self accessing the configurations for the
    # configurable class.  Unlike config_attr and config, nest does not
    # create accessors; the configurations must be accessed through
    # the instance config method.  Moreover, default attributes are not 
    # merged with the the input attributes.
    #
    #   class A
    #     include Configurable
    #     config :key, 'value'
    #
    #     def initialize(overrides={})
    #       initialize_config(overrides)
    #     end
    #   end
    #
    #   class B
    #     include Configurable
    #     nest :a, A
    #
    #     def initialize(overrides={})
    #       initialize_config(overrides)
    #     end
    #   end
    #
    #   b = B.new
    #   b.config[:a]                   # => {:key => 'value'}
    #
    # Nest may be provided a block which receives the first value for
    # the nested config and is expected to initialize an instance of
    # configurable_class.  In this case a reader for the instance is
    # created and access becomes quite natural.
    #
    #   class C
    #     include Configurable
    #     nest(:a, A) {|overrides| A.new(overrides) }
    #
    #     def initialize(overrides={})
    #       initialize_config(overrides)
    #     end
    #   end
    #
    #   c = C.new
    #   c.a.key                        # => "value"
    #
    #   c.a.key = "one"
    #   c.config[:a].to_hash           # => {:key => 'one'}
    #
    #   c.config[:a][:key] = 'two'
    #   c.a.key                        # => "two"
    #
    #   c.config[:a] = {:key => 'three'}
    #   c.a.key                        # => "three"
    # 
    # Nesting with an initialization block creates private methods
    # that config[:a] uses to read and write the instance configurations;
    # these methods are "#{key}_config" and "#{key}_config=" by default, 
    # but they may be renamed using the :reader and :writer attributes.
    #
    # Nest checks for recursive nesting and raises an error if
    # a recursive nest is detected.
    def nest(key, configurable_class, attributes={}, &block)
      unless configurable_class.kind_of?(Configurable::ClassMethods)
        raise ArgumentError, "not a Configurable class: #{configurable_class}" 
      end
      
      # register with Lazydoc
      attributes[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      
      # add some tracking attributes
      attributes[:receiver] ||= configurable_class
      
      reader = attributes.delete(:reader)
      writer = attributes.delete(:writer)
  
      if block_given?
        # define instance accessor methods
        instance_var = "@#{key}".to_sym
        reader = "#{key}_config" unless reader
        writer = "#{key}_config=" unless writer
    
        # the public accessor
        attr_reader key
        public(key)
  
        # the reader returns the config for the instance
        define_method(reader) do
          instance_variable_get(instance_var).config
        end
  
        # the writer initializes the instance if necessary,
        # or reconfigures the instance if it already exists
        define_method(writer) do |value|
          if instance_variable_defined?(instance_var) 
            instance_variable_get(instance_var).reconfigure(value)
          else
            instance_variable_set(instance_var, block.call(value))
          end
        end
        private(reader, writer)
      else
        reader = writer = nil
      end
      
      value = DelegateHash.new(configurable_class.configurations).update
      configurations[key] = Delegate.new(reader, writer, value, attributes)
  
      check_infinite_nest(configurable_class.configurations)
    end

    # Alias for Validation
    def c
      Validation
    end

    private
    
    # a helper to initialize configurations for the first time,
    # mainly implemented as a hook for the OrderedHash patch
    def initialize_configurations # :nodoc:
      @configurations ||= {}
    end
    
    # a helper method to make the default attributes for the specified block.  
    # Merges the default attributes for no block (nil) with the attributes
    # for the specified block
    def default_attributes(block=nil) # :nodoc:
      if block 
        DEFAULT_ATTRIBUTES[nil].merge(DEFAULT_ATTRIBUTES[block])
      else
        DEFAULT_ATTRIBUTES[nil].dup
      end
    end
    
    # helper to recursively check a set of 
    # configurations for an infinite nest
    def check_infinite_nest(configurations) # :nodoc:
      raise "infinite nest detected" if configurations == self.configurations
  
      configurations.each_pair do |key, config|
        config_hash = config.default(false)
    
        if config_hash.kind_of?(DelegateHash)
          check_infinite_nest(config_hash.delegates)
        end
      end
    end
  end
end

module Configurable
  class OrderedHash < Hash
    def initialize
      super
      @key_order = []
    end
    
    def []=(key, value)
      @key_order << key unless @key_order.include?(key)
      super
    end
  
    def each_pair
      keys.sort_by do |key|
        @key_order.index(key)
      end.each do |key|
        yield(key, fetch(key))
      end
    end
  end
  
  module ClassMethods
    # a helper to initialize configurations for the first time
    def initialize_configurations # :nodoc:
      @configurations ||= OrderedHash.new
    end
  end
end if RUBY_VERSION < '1.9'