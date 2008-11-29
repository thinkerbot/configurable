require 'configurable_class'

# Configurable enables the specification of configurations within a class definition.
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
#   c.config.class         # => Configurable::ConfigHash
#   c.config               # => {:one => 'one', :two => 'two', :three => 'three'}
#
# The <tt>config</tt> object acts as a forwarding hash; declared configurations
# map to accessors while undeclared configurations are stored internally:
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
# blocks which can be accessed through the class method 'c':
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
# As shown here, Configurations are inherited from the parent and may be
# overridden in subclasses.
#
# === Options
#
# Alternative reader and writer methods may be specified as options to config.
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
# Idiosyncratically, true, false, and nil may also be provided as 
# reader/writer options. 
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
module Configurable
  
  # Extends including classes with ConfigurableClass
  def self.included(mod) # :nodoc:
    mod.extend ConfigurableClass if mod.kind_of?(Class)
  end
  
  # A ConfigHash bound to self
  attr_reader :config
  
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
    
    @config = ConfigHash.new(delegates, self, store)
  end
end