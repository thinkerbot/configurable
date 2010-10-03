require 'configurable/module_methods'

# Configurable enables the specification of configurations within a class 
# definition.
#
#   class ConfigClass
#     include Configurable
#     config :one, 'one'
#     config :two, 'two'
#     config :three, 'three'
#   end
#
#   c = ConfigClass.new
#   c.config.class            # => Configurable::ConfigHash
#   c.config                  # => {:one => 'one', :two => 'two', :three => 'three'}
#
# Instances have a <tt>config</tt> object that acts like a forwarding hash; 
# configuration keys delegate to accessors while undeclared key-value pairs
# are stored internally:
#
#   c.config[:one] = 'ONE'
#   c.one                     # => 'ONE'
#
#   c.one = 1           
#   c.config                  # => {:one => 1, :two => 'two', :three => 'three'}
#
#   c.config[:undeclared] = 'value'
#   c.config.store            # => {:undeclared => 'value'}
#
# The writer for a configuration can be defined by providing a block to config.  
# The Validation module provides a number of common validation/transform 
# blocks accessible through the class method 'c':
#
#   class ValidationClass
#     include Configurable
#     config(:one, 'one') {|v| v.upcase }
#     config :two, 2, &c.integer
#   end
#
#   c = ValidationClass.new
#   c.config                  # => {:one => 'ONE', :two => 2}
#
#   c.one = 'aNothER'             
#   c.one                     # => 'ANOTHER'
#
#   c.two = -2
#   c.two                     # => -2
#   c.two = "3"
#   c.two                     # => 3
#   c.two = nil               # !> ValidationError
#   c.two = 'str'             # !> ValidationError
# 
# Note that config blocks are defined in class-context and will have access
# to variables outside the block (as you would expect).  For instance, these
# are analagous declarations:
#
#   class ExampleClass
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
#   class LiteralClass
#     config_attr :key, 'value' do |input|
#       @key = input.upcase
#     end
#   end
#
# Configurations are inherited and may be overridden in subclasses.  They may
# also be included from a module:
#
#   module A
#     include Configurable
#     config :a, 'a'
#     config :b, 'b'
#   end
#
#   class B
#     include A
#   end
#
#   class C < B
#     config :b, 'B'
#     config :c, 'C'
#   end
#
#   B.new.config.to_hash      # => {:a => 'a', :b => 'b'}
#   C.new.config.to_hash      # => {:a => 'a', :b => 'B', :c => 'C'} 
#
# Lastly, configurable classes may be nested through the nest method.  Nesting
# creates a configurable class with the configs defined in the nest block;
# nested configs may be accessed by chaining method calls, or through nested
# calls to config.
#
#   class NestingClass
#     include Configurable
#     config :one, 'one'
#     nest :two do
#       config :three, 'three'
#     end
#   end
#
#   c = NestingClass.new
#   c.config.to_hash          # => {:one => 'one', :two => {:three => 'three'}}
#
#   c.two.three = 'THREE'
#   c.config[:two][:three]    # => 'THREE'
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
# init::         When set to false, the config will not initialize itself. 
#                Specify when you manually initialize a config.
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
  
  # A ConfigHash bound to self.  Accessing configurations through config
  # is much slower (although sometimes more convenient) than through the
  # config accessors.
  attr_reader :config
  
  # Initializes config, if necessary, and then calls super.  If initialize
  # is overridden without calling super, be sure to call initialize_config
  # manually within the new initialize method.
  def initialize(*args)
    initialize_config unless instance_variable_defined?(:@config)
    super
  end
  
  # Reinitializes configurations in the copy such that the new object has
  # it's own set of configurations, separate from the original object.
  def initialize_copy(orig)
    super
    @config = ConfigHash.new(orig.config.store.dup, self)
  end

  private
  
  # Initializes config. Default config values are overridden as specified.
  def initialize_config(overrides={})
    @config = ConfigHash.new(overrides).bind(self)
  end
end