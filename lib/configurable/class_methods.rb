require 'configurable/config_hash'
require 'configurable/validation'

autoload(:ConfigParser, 'config_parser')

module Configurable
  
  # ClassMethods extends classes that include Configurable and provides methods
  # for declaring configurations.
  module ClassMethods
    
    # A hash of (key, Config) pairs tracking configs defined on self.  See
    # configurations for all configs declared across all ancestors.
    attr_reader :config_registry
    
    def self.initialize(base)  # :nodoc:
      unless base.instance_variable_defined?(:@config_registry)
        base.instance_variable_set(:@config_registry, {})
      end
      
      unless base.instance_variable_defined?(:@configurations)
        base.instance_variable_set(:@configurations, nil)
      end
    end
    
    # Parses configurations from argv in a non-destructive manner by generating
    # a ConfigParser using the configurations for self.  Returns an array like
    # [args, config] where the args are the arguments that remain after parsing,
    # and config is a hash of the parsed configs. The parser is yielded to
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
    
    # A hash of (key, Config) pairs representing all configurations defined
    # on this class or inherited from ancestors.  The configurations hash is
    # generated on each call to ensure it accurately reflects any configs
    # added on ancestors. This slows down initialization and config access
    # through instance.config.
    #
    # Call cache_configurations after all configs have been declared in order
    # to prevent regeneration of configurations and to significantly improve
    # performance.
    def configurations
      return @configurations if @configurations
      
      configurations = {}
      
      ancestors.reverse.each do |ancestor|
        next unless ancestor.kind_of?(ClassMethods)
        ancestor.config_registry.each_pair do |key, value|
          if value.nil?
            configurations.delete(key)
          else
            configurations[key] = value
          end
        end
      end
      
      configurations
    end
    
    # Caches the configurations hash so as to improve peformance.  Call
    # with on set to false to turn off caching.
    def cache_configurations(on=true)
      @configurations = nil
      @configurations = self.configurations if on
    end
    
    protected

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
    # init::                  When set to false the config will not initialize
    #                         during initialize_config. (default: true)
    # reader::                The method used to read the configuration.
    #                         (default: key)
    # writer::                The method used to write the configuration
    #                         (default: "#{key}=")
    #
    # Neither reader nor writer may be set to nil, but they may be set to
    # non-default values.  In that case, config_attr will register the method
    # names as provided, but it will not define the methods themselves.
    # Specifying true defines the default methods.  Specifying false makes
    # the config expect the default method name, but does not define the method
    # itself.
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
      dup = attributes.has_key?(:dup) ? attributes.delete(:dup) : nil
      config_registry[key] = Config.new(reader, writer, value, attributes, init, dup)
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
    # Nest uses the same attributes as config_attr, with a couple additions:
    #
    # Attribute::             Description            
    # const_name::            Determines the constant name of the configurable
    #                         class within the nesting class.  May be nil.
    #                         (default: key.to_s.capitalize)
    # type::                  By default set to :nest.
    #
    def nest(key, configurable_class=nil, attributes={}, &block)
      attributes = merge_attributes(block, attributes)
      attributes = {
        :reader => true,
        :writer => true,
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
      
      # set the new constant
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
      const_name = nil
      
      # define the reader.
      reader = define_attribute_method(:reader, attributes, key) do |attribute|
        attr_reader attribute
        public(attribute)
      end
      
      # define the writer.  the default the writer validates the
      # instance is the correct class then sets the instance variable
      instance_variable = "@#{key}".to_sym
      writer = define_attribute_method(:writer, attributes, "#{key}=") do |attribute|
        define_method(attribute) do |value|
          Validation.validate(value, [configurable_class])
          instance_variable_set(instance_variable, value)
        end
        public(attribute)
      end
      
      # define the configuration
      init = attributes.has_key?(:init) ? attributes.delete(:init) : true
      config_registry[key] = NestConfig.new(configurable_class, reader, writer, attributes, init)
      check_infinite_nest(configurable_class)
    end  
    
    # Removes a configuration much like remove_method removes a method.  The
    # reader and writer for the config are likewise removed.  Nested configs
    # can be removed using this method.
    #
    # Setting :reader or :writer to false in the options prevents those methods
    # from being removed.
    #
    def remove_config(key, options={})
      unless config_registry.has_key?(key)
        raise NameError.new("#{key.inspect} is not a config on #{self}")
      end
      
      options = {
        :reader => true,
        :writer => true
      }.merge(options)
      
      config = config_registry.delete(key)
      cache_configurations(@configurations != nil)
      
      undef_method(config.reader) if options[:reader]
      undef_method(config.writer) if options[:writer]
    end
    
    # Undefines a configuration much like undef_method undefines a method.  The
    # reader and writer for the config are likewise undefined.  Nested configs
    # can be undefined using this method.
    #
    # Setting :reader or :writer to false in the options prevents those methods
    # from being undefined.
    #
    # ==== Implementation Note
    #
    # Configurations are undefined by setting the key to nil in the registry.
    # Deleting the config is not sufficient because the registry needs to
    # convey to self and subclasses to not inherit the config from ancestors.
    #
    # This is unlike remove_config where the config is simply deleted from
    # the config_registry.
    #
    def undef_config(key, options={})
      # temporarily cache as an optimization
      configs = configurations
      unless configs.has_key?(key)
        raise NameError.new("#{key.inspect} is not a config on #{self}")
      end
      
      options = {
        :reader => true,
        :writer => true
      }.merge(options)
      
      config = configs[key]
      config_registry[key] = nil
      cache_configurations(@configurations != nil)
      
      undef_method(config.reader) if options[:reader]
      undef_method(config.writer) if options[:writer]
    end
    
    # Alias for Validation
    def c
      Validation
    end

    private
    
    def inherited(base) # :nodoc:
     ClassMethods.initialize(base)
     super
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