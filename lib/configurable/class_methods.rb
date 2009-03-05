require 'lazydoc'
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
      case reader = attributes.delete(:reader)
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
    # Nest may be provided a block which initializes an instance of
    # configurable_class.  In this case accessors for the instance
    # are created and access becomes quite natural.
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
    # The initialize block executes in class context, much like config.
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
    # Nest checks for recursive nesting and raises an error if a recursive nest
    # is detected.
    #
    # ==== Attributes
    #
    # Nesting with an initialization block creates the public accessor for the
    # instance, private methods to read and write the instance configurations,
    # and a private method to initialize the instance. The default names
    # for these methods are listed with the attributes to override them:
    #
    #   :instance_reader         key
    #   :instance_writer         "#{key}="
    #   :instance_initializer    "#{key}_initialize"
    #   :reader                  "#{key}_config_reader"
    #   :writer                  "#{key}_config_writer"
    #
    # These attributes are ignored if no block is given; true/false/nil
    # values are meaningless and will be treated as the default.
    #
    def nest(key, configurable_class=nil, attributes={}, &block)
      attributes = merge_attributes(block, attributes)
      attributes = {
        :instance_reader => true,
        :instance_writer => true,
        :initializer => true
      }.merge(attributes)
      
      # define the nested configurable
      if configurable_class
        raise "a block is not allowed when a configurable class is specified" if block_given?
      else
        configurable_class = Class.new { include Configurable }
        configurable_class.class_eval(&block) if block_given?
      end
      
      const_name = attributes.delete(:const_name) || key.to_s.capitalize
      const_set(const_name, configurable_class)
         
      # define instance reader
      instance_reader = define_attribute_method(:instance_reader, attributes, key) do |attribute|
        attr_reader(key)
        public(key)
      end
      
      # define instance writer
      instance_writer = define_attribute_method(:instance_writer, attributes, "#{key}=") do |attribute|
        attr_writer(key)
        public(attribute)
      end
      
      # define initializer
      initializer = define_attribute_method(:initializer, attributes, "#{key}_initializer") do |attribute|
        define_method(attribute) {|config| configurable_class.new.reconfigure(config) }
        private(attribute)
      end
      
      # define the reader
      reader = define_attribute_method(:reader, attributes, "#{key}_config") do |attribute|
        define_method(attribute) { send(instance_reader).config }
        private(attribute)
      end
      
      # define the writer
      writer = define_attribute_method(:writer, attributes, "#{key}_config=") do |attribute|
        define_method(attribute) do |value|
          if instance = send(instance_reader)
            instance.reconfigure(value)
          else
            send(instance_writer, send(initializer, value))
          end
        end
        private(attribute)
      end
      
      # define the configuration
      nested_config = DelegateHash.new(configurable_class.configurations)
      configurations[key] = Delegate.new(reader, writer, nested_config, attributes)
      
      check_infinite_nest(configurable_class.configurations)
    end  
    
    # Alias for Validation
    def c
      Validation
    end

    private
    
    # a helper to define methods that may be overridden in attributes.
    # yields the default to the block if the default is supposed to
    # be defined.  returns the symbolized method name.
    def define_attribute_method(name, attributes, default) # :nodoc:
      attribute = attributes.delete(name)
      
      case attribute
      when true
        # true means use the default and define the method
        attribute = default
        yield(attribute)
        
      when false
        # false means use the default, but let the user define the method
        attribute = default
        
      when nil
        # nil is not allowed
        raise "#{name.inspect} attribute cannot be nil"
      end
      # ... all other values specify what the method should be,
      # and lets the user define the method.

      attribute.to_sym
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
        if delegate.is_nest?
          check_infinite_nest(delegate.default(false).delegates)
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
  # each_pair.  OrderedHashPatches are used as the configurations object in 
  # Configurable classes for pre-1.9 ruby implementations and for nothing else.
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
    
    # Keys, sorted into insertion order
    def keys
      super.sort_by do |key|
        @insertion_order.index(key) || length
      end
    end
    
    # Yields each key-value pair to the block in insertion order.
    def each_pair
      keys.each do |key|
        yield(key, fetch(key))
      end
    end
    
    # Ensures the insertion order of duplicates is separate from parents.
    def initialize_copy(orig)
      super
      @insertion_order = orig.instance_variable_get(:@insertion_order).dup
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