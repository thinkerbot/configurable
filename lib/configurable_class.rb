require 'configurable/delegate_hash'
require 'configurable/validation'

module ConfigurableClass
  # A hash holding the class configurations.
  attr_reader :configurations

  def self.extended(base) # :nodoc:
    base.instance_variable_set(:@configurations, {})
  end

  def inherited(child) # :nodoc:
    configurations = {}
    @configurations.each_pair {|key, config| configurations[key] = config.dup } 
    child.instance_variable_set(:@configurations, configurations)
    super
  end
  
  protected
  
  # Declares a class configuration and generates the associated accessors. 
  # If a block is given, the <tt>key=</tt> method will set <tt>@key</tt> 
  # to the return of the block, which executes in class-context.  
  # Configurations are inherited, and can be overridden in subclasses. 
  #
  #   class SampleClass
  #     include Tap::Support::Configurable
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
      options = standard_attributes(block).merge(options)
    
      instance_variable = "@#{key}".to_sym
      config_attr(key, value, options) do |input|
        instance_variable_set(instance_variable, yield(input))
      end
    else
      config_attr(key, value, options)
    end
  end

  # Declares a class configuration and generates the associated accessors. 
  # If a block is given, the <tt>key=</tt> method will perform the block with
  # instance-context.  Configurations are inherited, and can be overridden 
  # in subclasses. 
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
  # Instances of a Configurable class may set configurations through config.
  # The config object is an DelegateHash which forwards read/write 
  # operations to the configuration accessors.  For example:
  #
  #   s = SampleClass.new
  #   s.config.class            # => Configurable::DelegateHash
  #   s.str                     # => 'value'
  #   s.config[:str]            # => 'value'
  #
  #   s.str = 'one'
  #   s.config[:str]            # => 'one'
  #   
  #   s.config[:str] = 'two' 
  #   s.str                     # => 'two'
  # 
  # Alternative reader and writer methods may be specified as an option;
  # in this case config_attr assumes the methods are declared elsewhere
  # and will not define the associated accessors.  
  # 
  #   class AlternativeClass
  #     include Configurable
  #
  #     config_attr :sym, 'value', :reader => :get_sym, :writer => :set_sym
  #
  #     def initialize
  #       initialize_config
  #     end
  #
  #     def get_sym
  #       @sym
  #     end
  #
  #     def set_sym(input)
  #       @sym = input.to_sym
  #     end
  #   end
  #
  #   alt = AlternativeClass.new
  #   alt.respond_to?(:sym)     # => false
  #   alt.respond_to?(:sym=)    # => false
  #   
  #   alt.config[:sym] = 'one'
  #   alt.get_sym               # => :one
  #
  #   alt.set_sym('two')
  #   alt.config[:sym]          # => :two
  #
  # Idiosyncratically, true, false, and nil may also be provided as 
  # reader/writer options. Specifying true is the same as using the 
  # default.  Specifying false or nil prevents config_attr from 
  # defining accessors; false sets the configuration to use 
  # the default reader/writer methods (ie <tt>key</tt> and <tt>key=</tt>,
  # which must be defined elsewhere) while nil prevents read/write
  # mapping of the config to a method.
  def config_attr(key, value=nil, options={}, &block)
    attributes = standard_attributes(block).merge(:reader => true, :writer => true, :lazydoc => true)
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
      raise(ArgumentError, "a block may not be specified without writer == true") 
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
    if options[:lazydoc]
    # caller.each do |line|
    #   case line
    #   when /in .config.$/ then next
    #   when Lazydoc::CALLER_REGEXP
    #     options[:desc] = Lazydoc.register($1, $3.to_i - 1, Lazydoc::Config)
    #     break
    #   end
    # end if options[:desc] == nil
    end
  
    configurations[key] = Configurable::Delegate.new(reader, writer, value)
  end

  # Alias for Configurable::Validation
  def c
    Validation
  end
  
  private
  
  Validation = Configurable::Validation
  
  def standard_attributes(block)
    case 
    when block == Validation::SWITCH 
      {:arg_type => :switch}
    when block == Validation::FLAG
      {:arg_type => :flag}
    when block == Validation::LIST
      {:arg_type => :list}
    when block == Validation::ARRAY 
      {:arg_name => "'[a, b, c]'"}
    when block == Validation::HASH 
      {:arg_name => "'{one: 1, two: 2}'"}
    else 
      {}
    end
  end
end