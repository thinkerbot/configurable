require 'configurable/module_methods'

# Configurable enables the specification of configurations within a class 
# definition.
#
#   class ConfigClass
#     include Configurable
# 
#     config :one, 'one'
#     config :two, 'two'
#     config :three, 'three'
#
#   end
#
#   c = ConfigClass.new
#   c.config.class         # => Configurable::ConfigHash
#   c.config               # => {:one => 'one', :two => 'two', :three => 'three'}
#
# Instances have a <tt>config</tt> object that acts like a forwarding hash; 
# configuration keys delegate to accessors while undeclared key-value pairs
# are stored internally:
#
#   c.config[:one] = 'ONE'
#   c.one                  # => 'ONE'
#
#   c.one = 1           
#   c.config               # => {:one => 1, :two => 'two', :three => 'three'}
#
#   c.config[:undeclared] = 'value'
#   c.config.store         # => {:undeclared => 'value'}
#
# The writer for a configuration can be defined by providing a block to config.  
# The Validation module provides a number of common validation/transform 
# blocks accessible through the class method 'c':
#
#   class SubClass < ConfigClass
#     config(:one, 'one') {|v| v.upcase }
#     config :two, 2, &c.integer
#   end
#
#   s = SubClass.new
#   s.config               # => {:one => 'ONE', :two => 2, :three => 'three'}
#
#   s.one = 'aNothER'             
#   s.one                  # => 'ANOTHER'
#
#   s.two = -2
#   s.two                  # => -2
#   s.two = "3"
#   s.two                  # => 3
#   s.two = nil            # !> ValidationError
#   s.two = 'str'          # !> ValidationError
# 
# Note that config blocks are defined in class-context and will have access
# to variables outside the block (as you would expect).  For instance, these
# are analagous declarations:
#
#   class ClassConfig
#     config :key, 'value' do |input|
#       input.upcase
#     end
#   end
#
#   class AnalagousClass
#     block = lambda {|input| input.upcase}
#
#     define_method(:key=) do |input|
#       @key = block.call(input)
#     end
#   end
#
# To have the block literally define the writer, use the config_attr method.
# Blocks provided to config_attr will have instance context and must set 
# the instance variable themselves.
#
#   class ConfigClass
#     config_attr :key, 'value' do |input|
#       @key = input.upcase
#     end
#   end
#
# Configurations are inherited and may be overridden in subclasses.
#
# === Attributes
#
# Alternative reader and writer methods may be specified as config attributes.
# When alternate methods are specified, Configurable assumes the methods are 
# declared elsewhere and will not define accessors.  
# 
#   class AlternativeClass
#     include Configurable
#
#     config_attr :sym, 'value', :reader => :get_sym, :writer => :set_sym
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
# Idiosyncratically, true and false may also be provided as reader/writer
# values.
#
# true::     Same as using the defaults, accessors are defined.
# false::    Sets the default reader/writer but does not define
#            the accessors (think 'define reader/writer' => false).
#
# Nil is not allowed as a value.
#
# ==== Non-reader/writer attributes
#
# Attributes provide metadata for how to use configurations in various contexts.
# In general, attributes can be used to set any metadata an application
# needs.  A few attributes are used internally by Configurable.
#
# Attribute::    Use::
# set_default::  When set to false, the delegate will not map a default value
#                during bind.  Specify when you manually initialize a config
#                variable.
# type::         Specifies the type of option ConfigParser generates for this
#                Config (ex: :switch, :flag, :list, :hidden)
# desc::         The description string used in the ConfigParser help
# long::         The long option (default: key)
# short::        The short option.
#
# Validation blocks have default attributes already assigned to them (ex type).
# In cases where a user-defined block gets used multiple times, it may be useful
# to register default attributes for that block.  To do so, use this pattern:
#
#   class AttributesClass
#     include Configurable
#     block = c.register(:type => :upcase) {|v| v.upcase }
#
#     config :a, 'A', &block
#     config :b, 'B', &block
#   end
#   
#   AttributesClass.configurations[:a][:type]   # => :upcase
#   AttributesClass.configurations[:b][:type]   # => :upcase
#
module Configurable
  autoload(:Utils, 'configurable/utils')

  # A ConfigHash bound to self
  attr_reader :config
  
  # Initializes config, if necessary, and then calls super.  If initialize
  # is overridden without calling super, be sure to call initialize_config
  # manually within the new initialize method.
  def initialize(*args)
    initialize_config unless instance_variable_defined?(:@config)
    super
  end

  # Reconfigures self with the given overrides. Only the 
  # specified configs are modified.
  #
  # Returns self.
  def reconfigure(overrides={})
    config.merge!(overrides)
    self
  end

  # Reinitializes configurations in the copy such that
  # the new object has it's own set of configurations,
  # separate from the original object.
  def initialize_copy(orig)
    super
    initialize_config(orig.config.dup)
  end

  protected
  
  # Opens the file specified by io and yield it to the block.  If io is an
  # IO, it will be yielded immediately, and the mode is ignored.  Nil io are
  # simply ignored.
  #
  # === Usage
  #
  # open_io is used to compliment the io validation, to ensure that if a file
  # is specified, it will be closed.
  #
  #   class IoSample
  #     include Configurable
  #     config :output, $stdout, &c.io    # can be an io or filepath
  #
  #     def say_hello
  #       open_io(output, 'w') do |io|
  #         io << 'hello!'
  #       end
  #     end
  #   end
  #
  # In short, this method provides a way to responsibly handle IO and file
  # configurations. 
  def open_io(io, mode='r')
    case io
    when String
      dir = File.dirname(io)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      File.open(io, mode) {|file| yield(file) }
    when Integer
      # note this does not close the io because, as far as I understand, 
      # valid integer file descriptors point to files that are already
      # open and presumably managed elsewhere
      yield IO.open(io, mode)
    when nil then nil
    else yield(io)
    end
  end

  # Initializes config. Default config values 
  # are overridden as specified by overrides.
  def initialize_config(overrides={}, log=false)
    @config = ConfigHash.new(self, overrides, false)
    configs = @config.configs
    
    initial_values = {}
    overrides.each_key do |key|
      if config = configs[key]

        unless config.init?
          key = configs.keys.find {|k| configs[k] == config }
          raise "initialization values are not allowed for: #{key.inspect}"
        end

        if initial_values.has_key?(config)
          key = configs.keys.find {|k| configs[k] == config }
          raise "multiple values map to config: #{key.inspect}"
        end

        initial_values[config] = overrides.delete(key)
      end
    end
    
    configs.each_pair do |key, config|
      next unless config.init?

      if initial_values.has_key?(config)
        config.set(self, initial_values[config])
      else
        config.init(self)
      end
    end
  end
end