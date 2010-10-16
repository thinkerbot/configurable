require 'configurable/module_methods'

# Configurable enables the specification of configurations within a class 
# definition.  Include and declare configs as below.
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
#   c.config.to_hash          # => {:one => 'one', :two => 'two', :three => 'three'}
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
  
  protected
  
  # Initializes config. Default config values are overridden as specified.
  def initialize_config(overrides={})
    @config = ConfigHash.new(overrides).bind(self)
  end
end