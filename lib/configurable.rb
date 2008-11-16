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
#   c.config.class         # => InstanceConfiguration
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
# As shown above, configurations are inherited from the parent and may be
# overridden in subclasses.  See ConfigurableClass for more details.
#
module Configurable
  
  # Extends including classes with ConfigurableClass
  def self.included(mod) # :nodoc:
    mod.extend ConfigurableClass if mod.kind_of?(Class)
  end
  
  # An InstanceConfiguration with configurations for self
  attr_reader :config
  
  # Reinitializes configurations in the copy such that
  # the new object has it's own set of configurations,
  # separate from the original object.
  def initialize_copy(orig)
    super
    initialize_config(orig.config)
  end
  
  protected
  
  # Initializes config to an DelegateHash. Default config values 
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
    
    @config = DelegateHash.new(delegates, self, store)
  end
end