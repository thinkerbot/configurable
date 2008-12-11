require 'configurable/class_methods'

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
#     def initialize(overrides={})
#       initialize_config(overrides)
#     end
#   end
#
#   c = ConfigClass.new
#   c.config.class         # => Configurable::DelegateHash
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
# Idiosyncratically, true, false, and nil may also be provided as reader/writer
# options. 
#
#   true     Same as using the defaults, accessors are defined.
#
#   false    Sets the default reader/writer but does not define
#            the accessors (think 'define reader/writer' => false).
#
#   nil      Does not define a reader/writer, and does not define
#            the accessors. In effect this will define a config
#            that does not map to the instance, but will be
#            present in instance.config
#
# ==== Non-reader/writer attributes
#
# Metadata for a config may be specified in attributes as well.  Attributes like
# :desc, and :type are used by ConfigParser, for instance, to determine how to
# represent the configuration on the command line.  Attributes are unstructured
# so they can accomodate metadata for multiple contexts (ex a web or desktop 
# interface), as needed.
#
module Configurable

  # Extends including classes with Configurable::ClassMethods
  def self.included(mod) # :nodoc:
    mod.extend ClassMethods if mod.kind_of?(Class)
  end

  # A DelegateHash bound to self
  attr_reader :config

  # Reconfigures self with the given overrides. Only the 
  # specified configs are modified.
  #
  # Returns self.
  def reconfigure(overrides={})
    overrides.each_pair do |key, value|
      config[key] = value
    end

    self
  end

  # Reinitializes configurations in the copy such that
  # the new object has it's own set of configurations,
  # separate from the original object.
  def initialize_copy(orig)
    super
    initialize_config(orig.config)
  end

  protected

  # Initializes config. Default config values 
  # are overridden as specified by overrides.
  def initialize_config(overrides={})
    delegates = self.class.configurations

    # note the defaults could be stored first and overridden
    # by the overrides, but this is likely more efficient
    # on average since delegates duplicate default values.
    store = {}
    overrides.each_pair do |key, value| 
      store[key] = value
    end
    delegates.each_pair do |key, delegate|
      store[key] = delegate.default unless store.has_key?(key)
    end

    @config = DelegateHash.new(delegates, store).bind(self)
  end
end