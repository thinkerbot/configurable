require 'lazydoc/attributes'
require 'configurable/config_hash'
require 'configurable/validation'
require 'configurable/desc'

# ConfigurableClass extends classes that include Configurable and
# provides methods for declaring configurations.
module ConfigurableClass
  include Lazydoc::Attributes
  
  # A hash holding the class configurations.
  attr_reader :configurations

  def self.extended(base) # :nodoc:
    caller.each_with_index do |line, index|
      case line
      when /\/configurable.rb/ then next
      when Lazydoc::CALLER_REGEXP
        base.instance_variable_set(:@source_file, File.expand_path($1))
        break
      end
    end
    
    base.instance_variable_set(:@configurations, {})
  end

  def inherited(child) # :nodoc:
    unless child.instance_variable_defined?(:@source_file)
      caller.first =~ Lazydoc::CALLER_REGEXP
      child.instance_variable_set(:@source_file, File.expand_path($1)) 
    end
    
    reverse_map = {}
    @configurations.each_pair do |key, config|
      (reverse_map[config] ||= []) << key 
    end
    
    configurations = {}
    reverse_map.each_pair do |config, keys|
      config = config.dup
      keys.each do |key|
        configurations[key] = config
      end
    end
    
    child.instance_variable_set(:@configurations, configurations)
    super
  end
  
  # Returns the lazydoc for self.  Resolve will recursively
  # resolve superclass lazydocs.
  #--
  # what about nested configurables?
  #
  # def lazydoc(resolve=true)
  #   if resolve 
  #     Lazydoc.resolve_comments(config_comments)
  #   end
  #   super
  # end
  
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
  def config(key, value=nil, options={}, &block)
    if block_given?
      options = Configurable::Validation::ATTRIBUTES[block].merge(options)
    
      instance_variable = "@#{key}".to_sym
      config_attr(key, value, options) do |input|
        instance_variable_set(instance_variable, yield(input))
      end
    else
      config_attr(key, value, options)
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
  def config_attr(key, value=nil, options={}, &block)
    attributes = Configurable::Validation::ATTRIBUTES[block].merge(
      :reader => true, 
      :writer => true, 
      :indifferent_access => true)
    attributes.merge!(options)
  
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
    
    # register with Lazydoc so that all extra documentation can be extracted
    caller.each do |line|
      case line
      when /in .config.$/ then next
      when Lazydoc::CALLER_REGEXP
        attributes[:desc] = Lazydoc.register($1, $3.to_i - 1, Configurable::Desc)
        break
      end
    end unless attributes[:desc]
    
    config = Configurable::Config.new(key, value, reader, writer, attributes)

    if attributes.delete(:indifferent_access)
      configurations[key.to_sym] = config
      configurations[key.to_s] = config
    else
      configurations[key] = config
    end
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
  # but they may be renamed using the :reader and :writer options.
  #
  # Nest checks for recursive nesting and raises an error if
  # a recursive nest is detected.
  #
  def nest(key, configurable_class, options={})
    unless configurable_class.kind_of?(ConfigurableClass)
      raise ArgumentError, "not a ConfigurableClass: #{configurable_class}" 
    end

    reader = options.delete(:reader)
    writer = options.delete(:writer)
    
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
          instance_variable_set(instance_var, yield(value))
        end
      end
      private(reader, writer)
    else
      reader = writer = nil
    end
    
    # register with Lazydoc so that all extra documentation can be extracted
    caller.each do |line|
      case line
      when /in .config.$/ then next
      when Lazydoc::CALLER_REGEXP
        options[:desc] = Lazydoc.register($1, $3.to_i - 1, Configurable::Desc)
        break
      end
    end unless options[:desc]
    
    value = Configurable::ConfigHash.new(configurable_class.configurations).update
    config = Configurable::Config.new(key, value, reader, writer, options)

    if options[:indifferent_access]
      configurations[key.to_sym] = config
      configurations[key.to_str] = config
    else
      configurations[key] = config
    end
    
    check_infinite_nest(configurable_class.configurations)
  end
  
  # Alias for Validation
  def c
    Configurable::Validation
  end
  
  private
  
  # helper to recursively check a set of 
  # configurations for an infinite nest
  def check_infinite_nest(configurations) # :nodoc:
    raise "infinite nest detected" if configurations == self.configurations
    
    configurations.each_pair do |key, config|
      config_hash = config.default(false)
      
      if config_hash.kind_of?(Configurable::ConfigHash)
        check_infinite_nest(config_hash.delegates)
      end
    end
  end
end