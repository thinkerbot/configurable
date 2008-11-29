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
    
    configurations = {}
    @configurations.each_pair {|key, config| configurations[key] = config.dup } 
    child.instance_variable_set(:@configurations, configurations)
    super
  end
  
  # Returns the lazydoc for self.
  # def lazydoc(resolve=true)
  #   Lazydoc.resolve_comments(configurations.code_comments) if resolve
  #   super
  # end
  
  # Loads the contents of path as YAML.  Returns an empty hash if the path 
  # is empty, does not exist, or is not a file.
  def load_config(path)
    # the last check prevents YAML from auto-loading itself for empty files
    return {} if path == nil || !File.file?(path) || File.size(path) == 0
    YAML.load_file(path) || {}
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
    attributes = Configurable::Validation::ATTRIBUTES[block].merge(:reader => true, :writer => true)
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
        options[:desc] = Lazydoc.register($1, $3.to_i - 1, Configurable::Desc)
        break
      end
    end unless options[:desc]
  
    configurations[key] = Configurable::Config.new(reader, writer, value, options)
  end
  
  # Alias for Validation
  def c
    Configurable::Validation
  end
  
end