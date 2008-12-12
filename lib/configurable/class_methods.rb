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
      attributes = merge_attributes(block, attributes)
      
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
      attributes = merge_attributes(block, attributes)
      
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
    # the instance config method.
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
    # Nest may be provided a block which receives the nested config 
    # and is expected to initialize an instance of configurable_class.  
    # In this case a reader for the instance is created and access 
    # becomes quite natural.
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
    # The initialize block for nest executes in class context, much
    # like config.
    #
    #   # An equivalent class to illustrate class-context
    #   class EquivalentClass
    #     attr_reader :a, A
    #
    #     INITIALIZE_BLOCK = lambda {|overrides| A.new(overrides) }
    #
    #     def initialize(overrides={})
    #       @a = INITIALIZE_BLOCK.call(overrides[:a] || {})
    #     end
    #   end
    #
    # ==== Attributes
    #
    # Nesting with an initialization block creates the public reader for the 
    # instance, and private methods to read and write the instance 
    # configurations, and to initialize the nested instance. The default names
    # for these methods are listed with the attributes to override them:
    #
    #   :instance_reader         key
    #   :instance_initializer    "#{key}_initialize"
    #   :reader                  "#{key}_config_reader"
    #   :writer                  "#{key}_config_writer"
    #
    # These attributes are ignored if no block is given; true/false/nil
    # values are meaningless and will be treated as the default.
    #
    # Nest checks for recursive nesting and raises an error if
    # a recursive nest is detected.
    def nest(key, configurable_class, attributes={}, &block)
      attributes = merge_attributes(block, attributes)
      
      if block_given?
        instance_variable = "@#{key}".to_sym
        nest_attr(key, configurable_class, attributes) do |input|
          instance_variable_set(instance_variable, yield(input))
        end
      else
        nest_attr(key, configurable_class, attributes)
      end
    end  
    
    # Same as nest, except the initialize block executes in instance-context.
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
    #   # An equivalent class to illustrate instance-context
    #   class EquivalentClass
    #     attr_reader :a, A
    #
    #     def a_initialize(overrides)
    #       A.new(overrides)
    #     end
    #
    #     def initialize(overrides={})
    #       @a = send(:a_initialize, overrides[:a] || {})
    #     end
    #   end
    #
    def nest_attr(key, configurable_class, attributes={}, &block)
      unless configurable_class.kind_of?(Configurable::ClassMethods)
        raise ArgumentError, "not a Configurable class: #{configurable_class}" 
      end
      
      attributes = merge_attributes(block, attributes)
      
      # add some tracking attributes
      attributes[:receiver] ||= configurable_class
      
      # remove attributes modifiying method defaults
      instance_reader = attributes.delete(:instance_reader)
      initializer = attributes.delete(:instance_initializer)
      reader = attributes.delete(:reader)
      writer = attributes.delete(:writer)
      
      if block_given?
        # define instance accessor methods
        instance_reader = boolean_select(instance_reader, key)
        instance_var = "@#{instance_reader}".to_sym
        
        initializer = boolean_select(reader, "#{key}_initialize")
        reader = boolean_select(reader, "#{key}_config_reader")
        writer = boolean_select(writer, "#{key}_config_writer")
        
        # the public accessor
        attr_reader instance_reader
        public(instance_reader)
        
        # the initializer
        define_method(initializer, &block)

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
            instance_variable_set(instance_var, send(initializer, value))
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
    
    # a helper to select a value or the default, if the default is true,
    # false, or nil.  used by nest_attr to handle attributes
    def boolean_select(value, default) # :nodoc:
      case value
      when true, false, nil then default
      else value
      end
    end
    
    # a helper to initialize configurations for the first time,
    # mainly implemented as a hook for OrderedHashPatch
    def initialize_configurations # :nodoc:
      @configurations ||= {}
    end
    
    # a helper method to merge the default attributes for the block with
    # the input attributes.  also registers a Trailer description.
    def merge_attributes(block, attributes) # :nodoc:
      defaults = DEFAULT_ATTRIBUTES[nil].dup
      defaults.merge!(DEFAULT_ATTRIBUTES[block]) if block
      defaults.merge!(attributes)
      
      # register with Lazydoc
      defaults[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer, 2)
      
      defaults
    end
    
    # helper to recursively check for an infinite nest
    def check_infinite_nest(delegates) # :nodoc:
      raise "infinite nest detected" if delegates == self.configurations
      
      delegates.each_pair do |key, delegate|
        default = delegate.default(false)
    
        if default.kind_of?(DelegateHash)
          check_infinite_nest(default.delegates)
        end
      end
    end
  end
end

module Configurable
  
  # Beginning with ruby 1.9, Hash tracks the order of insertion and methods
  # like each_pair return pairs in order.  Configurable leverages this feature
  # to keep configurations in order for the command line documentation produced
  # by ConfigParser.
  #
  # Pre-1.9 ruby implementations require a patched Hash that tracks insertion
  # order.  This very thin subclass of hash does that for ASET insertions and
  # each_pair.  It is used exclusively as the configurations object in 
  # Configurable classes.
  class OrderedHashPatch < Hash
    def initialize
      super
      @insertion_order = []
    end
    
    # ASET insertion, tracking insertion order.
    def []=(key, value)
      @insertion_order << key unless @insertion_order.include?(key)
      super
    end
    
    # Yields each key-value pair to the block in insertion order.
    def each_pair
      keys.sort_by do |key|
        @insertion_order.index(key)
      end.each do |key|
        yield(key, fetch(key))
      end
    end
  end
  
  module ClassMethods
    undef_method :initialize_configurations
    
    # applies OrderedHashPatch
    def initialize_configurations # :nodoc:
      @configurations ||= OrderedHashPatch.new
    end
  end
end if RUBY_VERSION < '1.9'