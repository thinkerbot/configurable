require 'configurable/config_hash'
require 'configurable/indifferent_access'
require 'configurable/validation'

autoload(:ConfigParser, 'config_parser')

module Configurable
  
  # ClassMethods extends classes that include Configurable and
  # provides methods for declaring configurations.
  module ClassMethods
    CONFIGURATIONS_CLASS = Hash
    
    # A hash of (key, Config) pairs tracking configs defined on self.
    attr_reader :config_registry
    
    def self.initialize(child)
      unless child.instance_variable_defined?(:@config_registry)
        child.instance_variable_set(:@config_registry, CONFIGURATIONS_CLASS.new)
      end
      
      unless child.instance_variable_defined?(:@use_indifferent_access)
        child.instance_variable_set(:@use_indifferent_access, true)
      end
    end
    
    # Parses configurations from argv in a non-destructive manner by generating
    # a ConfigParser using the configurations for self.  Returns an array like
    # [args, config] where the args are the arguments that remain after parsing,
    # and config is a hash of the parsed configs. The parser will is yielded to
    # the block, if given, to register additonal options.  
    #
    # See ConfigParser#parse for more information.
    def parse(argv=ARGV, options={}) # :yields: parser
      parse!(argv.dup, options)
    end
    
    # Same as parse, but removes parsed args from argv.
    def parse!(argv=ARGV, options={})
      parser = ConfigParser.new
      parser.add(configurations)
      
      args = parser.parse!(argv, options)
      [args, parser.config]
    end
    
    def configurations
      configurations = CONFIGURATIONS_CLASS.new
      configurations.extend(IndifferentAccess) if @use_indifferent_access
      
      ancestors.reverse.each do |ancestor|
        next unless ancestor.kind_of?(ClassMethods)
        configurations.merge!(ancestor.config_registry)
      end
      
      configurations
    end
    
    protected

    # Sets configurations to symbolize keys for AGET ([]) and ASET([]=)
    # operations, or not.  By default, configurations will use
    # indifferent access.
    def use_indifferent_access(input=true)
      @use_indifferent_access = input
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
    # === Attributes
    #
    # Several attributes may be specified to modify how a config is constructed.
    # Attribute keys should be specified as symbols.
    #
    # Attribute::             Description            
    # reader::                The method used to read the configuration.
    #                         (default: key)
    # writer::                The method used to write the configuration
    #                         (default: "#{key}=")
    #
    # Neither attribute may be set to nil, but they may be set to non-default
    # values.  In that case, config_attr will register the method names as
    # provided, but it will not define the methods themselves. Specifying true
    # uses and defines the default methods.  Specifying false uses the default
    # method name, but does not define the method itself.
    #
    # Any additional attributes are registered with the configuration.
    def config_attr(key, value=nil, attributes={}, &block)
      attributes = merge_attributes(block, attributes)
      
      # define the reader
      reader = define_attribute_method(:reader, attributes, key) do |attribute|
        attr_reader(attribute) 
        public(attribute)
      end
      
      # define the writer
      if block_given? && attributes[:writer] != true
        raise ArgumentError, "a block may not be specified without writer == true"
      end
      
      writer = define_attribute_method(:writer, attributes, "#{key}=") do |attribute|
        block_given? ? define_method(attribute, &block) : attr_writer(key)
        public(attribute)
      end
      
      # define the configuration
      init = attributes.has_key?(:init) ? attributes.delete(:init) : true
      config_registry[key] = Config.new(reader, writer, value, init, attributes)
    end
    
    # Adds nested configurations to self.  Nest creates a new configurable
    # class using the block, and provides accessors to an instance of the
    # new class.  Everything is set up so you can access configs through
    # the instance or through config.
    #
    #   class A
    #     include Configurable
    #
    #     config :key, 'one'
    #     nest :nest do
    #       config :key, 'two'
    #     end
    #   end
    #
    #   a = A.new
    #   a.key                     # => 'one'
    #   a.config[:key]            # => 'one'
    #
    #   a.nest.key                # => 'two'
    #   a.config[:nest][:key]     # => 'two'
    # 
    #   a.nest.key = 'TWO'
    #   a.config[:nest][:key]     # => 'TWO'
    #
    #   a.config[:nest][:key] = 2
    #   a.nest.key                # => 2
    #
    #   a.config.to_hash          # => {:key => 'one', :nest => {:key => 2}}
    #   a.nest.config.to_hash     # => {:key => 2}
    #   a.nest.class              # => A::Nest
    #
    # An existing configurable class may be provided instead of using the block
    # to define a new configurable class.  Recursive nesting is supported.
    #
    #   class B
    #     include Configurable
    #
    #     config :key, 1, &c.integer
    #     nest :nest do 
    #       config :key, 2, &c.integer
    #       nest :nest do
    #         config :key, 3, &c.integer
    #       end
    #     end
    #   end
    #
    #   class C
    #     include Configurable
    #     nest :a, A
    #     nest :b, B
    #   end
    #
    #   c = C.new
    #   c.b.key = 7
    #   c.b.nest.key = "8"
    #   c.config[:b][:nest][:nest][:key] = "9"
    #
    #   c.config.to_hash
    #   # => {
    #   # :a => {
    #   #   :key => 'one',
    #   #   :nest => {:key => 'two'}
    #   # },
    #   # :b => {
    #   #   :key => 7,
    #   #   :nest => {
    #   #     :key => 8,
    #   #     :nest => {:key => 9}
    #   #   }
    #   # }}
    #
    # === Attributes
    #
    # Nest provides a number of attributes that can modify how a nest is
    # constructed.  Attribute keys should be specified as symbols.
    #
    # Attribute::             Description            
    # const_name::            Determines the constant name of the configurable
    #                         class within the nesting class.  May be nil.
    #                         (default: key.to_s.capitalize)
    # instance_reader::       The method accessing the nested instance. (default: key)
    # instance_writer::       The method to set the nested instance. (default: "#{key}=")
    # reader::                The method used to read the instance config.
    #                         (default: "#{key}_config_reader")
    # writer::                The method used to reconfigure the instance. 
    #                         (default: "#{key}_config_writer")
    #
    # Except for const_name, these attributes are used to define methods
    # required for nesting to work properly.  None of the method attributes may
    # be set to nil, but they may be set to non-default values.  In that case,
    # nest will register the method names as provided, but it will not define
    # the methods themselves.  The user must define methods with the following
    # functionality:
    #
    # Attribute::             Function          
    # instance_reader::       Returns the instance of the configurable class 
    #                         (initializing if necessary, by default nest initializes
    #                         using configurable_class.new)
    # instance_writer::       Inputs and sets the instance of the configurable class
    # reader::                Returns instance.config
    # writer::                Reconfigures instance using the input overrides, or
    #                         sets instance if provided.
    #
    # Methods can be public or otherwise.  Specifying true uses and defines the
    # default methods.  Specifying false uses the default method name, but does
    # not define the method itself.
    #
    # Any additional attributes are registered with the configuration.
    def nest(key, configurable_class=nil, attributes={}, &block)
      attributes = merge_attributes(block, attributes)
      attributes = {
        :instance_reader => true,
        :instance_writer => true,
        :type => :nest
      }.merge(attributes)
      
      # define the nested configurable
      if configurable_class
        if block_given?
          configurable_class = Class.new(configurable_class)
          configurable_class.class_eval(&block)
        end
      else
        configurable_class = Class.new { include Configurable }
        configurable_class.class_eval(&block) if block_given?
      end
      
      # set the new constant (todo: make into a separate method so const_name is gc'ed)
      const_name = if attributes.has_key?(:const_name) 
        attributes.delete(:const_name) 
      else
        key.to_s.capitalize
      end
      
      if const_name
        # this prevents a warning in cases where the nesting
        # class defines the configurable_class
        unless const_defined?(const_name) && const_get(const_name) == configurable_class
          const_set(const_name, configurable_class)
        end
      end
      
      # define the instance reader.
      instance_variable = "@#{key}".to_sym
      reader = define_attribute_method(:instance_reader, attributes, key) do |attribute|
        define_method(attribute) do
          if instance_variable_defined?(instance_variable)
            instance_variable_get(instance_variable)
          else
            nil
          end
        end
        public(attribute)
      end
      
      # define the instance writer.  the default instance writer validates the
      # nested instance is the correct class then sets the instance variable
      writer = define_attribute_method(:instance_writer, attributes, "#{key}=") do |attribute|
        define_method(attribute) do |value|
          Validation.validate(value, [configurable_class])
          instance_variable_set(instance_variable, value)
        end
        public(attribute)
      end
      
      # define the configuration
      init = attributes.has_key?(:init) ? attributes.delete(:init) : true
      config_registry[key] = NestConfig.new(configurable_class, reader, writer, init, attributes)
      check_infinite_nest(configurable_class)
    end  
    
    # Alias for Validation
    def c
      Validation
    end

    private
    
    def inherited(base)
     ClassMethods.initialize(base)
     super
    end
    
    def each_ancestor
      yield(self)
    
      blank, *ancestors = self.ancestors
      ancestors.each do |ancestor|
        yield(ancestor) if ancestor.kind_of?(ClassMethods)
      end
    
      nil
    end
    
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
    def check_infinite_nest(klass) # :nodoc:
      raise "infinite nest detected" if klass == self
      
      klass.configurations.each_value do |delegate|
        if delegate.kind_of?(NestConfig)
          check_infinite_nest(delegate.nest_class)
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
    
    # Merges another into self in a way that preserves insertion order.
    def merge!(another)
      another.each_pair do |key, value|
        self[key] = value
      end
    end
    
    # Ensures the insertion order of duplicates is separate from parents.
    def initialize_copy(orig)
      super
      @insertion_order = orig.instance_variable_get(:@insertion_order).dup
    end
    
    # Overridden to load an array of [key, value] pairs in order (see to_yaml).
    # The default behavior for loading from a hash of key-value pairs is
    # preserved, but the insertion order will not be preserved.
    def yaml_initialize( tag, val )
      @insertion_order ||= []
     
      if Array === val
        val.each do |k, v|
          self[k] = v
        end
      else
        super
      end
    end
    
    # Overridden to preserve insertion order by serializing self as an array
    # of [key, value] pairs.
    def to_yaml( opts = {} )
      YAML::quick_emit( object_id, opts ) do |out|
        out.seq( taguri, to_yaml_style ) do |seq|
          each_pair do |key, value|
            seq.add( [key, value] )
          end
        end
      end
    end
  end
  
  module ClassMethods
    remove_const(:CONFIGURATIONS_CLASS)
    CONFIGURATIONS_CLASS = OrderedHashPatch
  end
end if RUBY_VERSION < '1.9'