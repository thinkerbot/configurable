require 'lazydoc'
require 'configurable/config_type'
require 'configurable/config_hash'
require 'configurable/conversions'

module Configurable
  
  # Hash of default config types (bool, integer, float, string).
  DEFAULT_CONFIG_TYPES = {
    :bool    => ConfigType.new(TrueClass, FalseClass).cast {|value| ConfigType.cast_to_bool(value) },
    :integer => ConfigType.new(Integer).cast {|value| Integer(value) },
    :float   => ConfigType.new(Float).cast   {|value| Float(value) },
    :string  => ConfigType.new(String).cast  {|value| String(value) }
  }
  
  # ClassMethods extends classes that include Configurable and provides methods
  # for declaring configurations.
  module ClassMethods
    include ConfigClasses
    
    # A hash of (key, Config) pairs tracking configs defined on self.  See the
    # configs method for all configs declared across all ancestors.
    attr_reader :config_registry
    
    # A hash of (key, ConfigType) pairs tracking config_types defined on self.
    # See the config_types method for all config_types declared across all
    # ancestors.
    attr_reader :config_type_registry
    
    def self.initialize(base) # :nodoc:
      base.reset_configs
      unless base.instance_variable_defined?(:@config_registry)
        base.instance_variable_set(:@config_registry, {})
      end
      
      base.reset_config_types
      unless base.instance_variable_defined?(:@config_type_registry)
        base.instance_variable_set(:@config_type_registry, {})
      end
    end
    
    # A hash of (key, Config) pairs representing all configs defined on this
    # class or inherited from ancestors.  The configs hash is memoized for
    # performance.  Call reset_configs if configs needs to be recalculated for
    # any reason.
    #
    # Configs is extended with the Conversions module.
    def configs
      @configs ||= begin
        configs = {}
      
        ancestors.reverse.each do |ancestor|
          next unless ancestor.kind_of?(ClassMethods)
          ancestor.config_registry.each_pair do |key, value|
            if value.nil?
              configs.delete(key)
            else
              configs[key] = value
            end
          end
        end
        
        configs.extend Conversions
        configs
      end
    end
    
    # Resets configs such that they will be recalculated.
    def reset_configs
      @configs = nil
    end
    
    # A hash of (key, ConfigType) pairs representing all config_types defined
    # on this class or inherited from ancestors.  The config_types hash is
    # memoized for performance.  Call reset_config_types if config_types needs
    # to be recalculated for any reason.
    def config_types
      @config_types ||= begin
        config_types = Configurable::DEFAULT_CONFIG_TYPES.dup
      
        ancestors.reverse.each do |ancestor|
          next unless ancestor.kind_of?(ClassMethods)
          ancestor.config_type_registry.each_pair do |key, value|
            if value.nil?
              config_types.delete(key)
            else
              config_types[key] = value
            end
          end
        end
      
        config_types
      end
    end
    
    # Resets config_types such that they will be recalculated.
    def reset_config_types
      @config_types = nil
    end
    
    protected
    
    # Defines and registers an instance of config_class with the specified key
    # and attrs. Unless attrs specifies a :reader or :writer, the
    # corresponding attr accessors will be defined for the config name (which
    # by default is the key). 
    def define_config(key, attrs={}, config_class=Config)
      reader = attrs[:reader]
      writer = attrs[:writer]
      
      config = config_class.new(key, attrs)
      
      attr_reader(config.name) unless reader
      attr_writer(config.name) unless writer
      
      config_registry[config.key] = config
      reset_configs
      config
    end
    
    # Defines a config after guessing or setting some standard values into
    # attrs. Specifically:
    #
    # * :default is the default
    # * :caster is the caster block (if provided)
    # * :desc is set using Lazydoc (unless already set)
    # * :list is set to true for array defaults (unless already set)
    #
    # In addition config also guesses the type of a config (if not manually
    # specified by :type) and merges in any attributes for the corresponding
    # config_type.  The class of the config is guessed from the attrs, based
    # on the :list and :options attributes using this logic:
    #
    #   :list  :otions   config_class
    #   ---------------------------
    #   false  false     Config
    #   true   false     List
    #   false  true      Select
    #   true   true      ListSelect
    #
    # == Usage Note
    #
    # Config is meant to be a convenience method.  It gets most things right
    # but if the attrs logic is too convoluted (and at times it is) then
    # define configs manually with the define_config method.
    def config(key, default=nil, attrs={}, &caster)
      attrs[:default] = default
      attrs[:caster]  = caster if caster
      attrs[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      attrs[:list] ||= default.kind_of?(Array)
      
      attrs = merge_config_type_attrs(attrs)
      define_config(key, attrs, guess_config_class(attrs))
    end
    
    # Defines a NestConfig after guessing or setting some standard attrs.  The
    # default (ie configurable_class) used by the nest config can be defined
    # by the block, or specified using the :class option.  If desired the
    # configurable_class can be specified instead of an options hash.  In all
    # cases the configurable_class is set as a constant into self by the
    # capitalized key.  For example these three are equivalent:
    #
    #   class A
    #     include Configurable
    #     nest :b do
    #       config :c
    #     end
    #   end
    #
    #   class A
    #     class B
    #       include Configurable
    #       config :c
    #     end
    #
    #     include Configurable
    #     nest :b, B
    #   end
    #
    #   class A
    #     class B
    #       include Configurable
    #       config :c
    #     end
    #     include Configurable
    #     define_config(:b, {:default => B}, NestClass)
    #   end
    #
    # If :class is provided with a block then the class is used as the
    # superclass for the configurable_class defined by the block.  The
    # constant name for the configurable_class can be manually set with
    # :const_name.
    #
    # Attributes will be any leftover options. As with config, nest takes a
    # guess at a couple attributes:
    #
    # * :default is the configurable_class as defined above
    # * :desc is set using Lazydoc (unless already set)
    #
    # In addition, like config, nest will guesses the type of a config (if not
    # manually specified by :type) and merges in any attributes for the
    # corresponding config_type.
    #
    # == Usage Note
    #
    # Nest is meant to be a convenience method.  It gets most things right but
    # if the options logic is too convoluted (and at times it is) then define
    # configs manually with the define_config method.
    def nest(key, options={}, &block)
      options = {:class => options} unless options.kind_of?(Hash)
      base_class = options.delete(:class)
      const_name = options.delete(:const_name) || key.to_s.capitalize
      
      configurable_class = begin
        case
        when base_class.nil? then Class.new { include Configurable }
        when block           then Class.new(base_class)
        else base_class
        end
      end
      
      if const_name
        unless const_defined?(const_name) && const_get(const_name) == configurable_class
          const_set(const_name, configurable_class)
        end
      end
      
      configurable_class.class_eval(&block) if block
      check_infinite_nest(configurable_class)
      
      attrs = options
      attrs[:desc]  ||= Lazydoc.register_caller(Lazydoc::Trailer)
      attrs[:default] = configurable_class
      attrs = merge_config_type_attrs(attrs)
      
      define_config(key, options, Nest)
    end
    
    # Removes a config much like remove_method removes a method.  The reader
    # and writer for the config are likewise removed.  Nested configs can be
    # removed using this method.
    #
    # Setting :reader or :writer to false in the options prevents those
    # methods from being removed.
    def remove_config(key, options={})
      unless config_registry.has_key?(key)
        raise NameError.new("#{key.inspect} is not a config on #{self}")
      end
      
      options = {
        :reader => true,
        :writer => true
      }.merge(options)
      
      config = config_registry.delete(key)
      reset_configs
      
      remove_method(config.reader) if options[:reader]
      remove_method(config.writer) if options[:writer]
      
      config
    end
    
    # Undefines a config much like undef_method undefines a method.  The
    # reader and writer for the config are likewise undefined.  Nested configs
    # can be undefined using this method.
    #
    # Setting :reader or :writer to false in the options prevents those
    # methods from being undefined.
    #
    # ==== Implementation Note
    #
    # Configurations are undefined by setting the key to nil in the registry.
    # Deleting the config is not sufficient because the registry needs to
    # convey to self and subclasses to not inherit the config from ancestors.
    #
    # This is unlike remove_config where the config is simply deleted from the
    # config_registry.
    def undef_config(key, options={})
      unless configs.has_key?(key)
        raise NameError.new("#{key.inspect} is not a config on #{self}")
      end
      
      options = {
        :reader => true,
        :writer => true
      }.merge(options)
      
      config = configs[key]
      config_registry[key] = nil
      reset_configs
      
      undef_method(config.reader) if options[:reader]
      undef_method(config.writer) if options[:writer]
      
      config
    end
    
    # Defines a named config type to match the specified classes. The caster
    # block, if provided, is set as the default :caster attribute. Other
    # default attributes may be specified with a hash given as the last
    # matcher.
    def config_type(type, *matchers, &caster)
      config_type = ConfigType.new(*matchers).cast(&caster)
      config_type_registry[type] = config_type
      reset_config_types
      
      config_type
    end
    
    # Removes a config_type much like remove_method removes a method.
    def remove_config_type(type)
      unless config_type_registry.has_key?(type)
        raise NameError.new("#{type.inspect} is not a config_type on #{self}")
      end
      
      config_type = config_type_registry.delete(type)
      reset_config_types
      config_type
    end
    
    # Undefines a config_type much like undef_method undefines a method.
    #
    # ==== Implementation Note
    #
    # ConfigTypes are undefined by setting the key to nil in the registry.
    # Deleting the config_type is not sufficient because the registry needs to
    # convey to self and subclasses to not inherit the config_type from
    # ancestors.
    #
    # This is unlike remove_config_type where the config_type is simply
    # deleted from the config_type_registry.
    def undef_config_type(type)
      unless config_types.has_key?(type)
        raise NameError.new("#{type.inspect} is not a config_type on #{self}")
      end
      
      config_type = config_type_registry[type]
      config_type_registry[type] = nil
      reset_config_types
      config_type
    end
    
    private
    
    def inherited(base) # :nodoc:
      ClassMethods.initialize(base)
      super
    end
    
    def guess_config_class(attrs) # :nodoc:
      attrs[:list] ? List : Config
    end
    
    def guess_config_type(attrs) # :nodoc:
      default = attrs[:default]
      guess_value = default.kind_of?(Array) ? default.first : default
      
      guesses = []
      config_types.each_pair do |type, config_type|
        if config_type === guess_value
          guesses << type
        end
      end
      
      if guesses.length > 1
        raise "multiple guesses for config type: #{value.inspect} #{guesses.inspect}"
      end
      
      guesses.at(0)
    end
    
    def merge_config_type_attrs(attrs) # :nodoc:
      type = attrs.has_key?(:type) ? attrs[:type] : guess_config_type(attrs)
      if config_type = config_types[type]
        attrs = config_type.default_attrs.merge(attrs)
      end
      attrs
    end
    
    # helper to recursively check for an infinite nest
    def check_infinite_nest(klass) # :nodoc:
      raise "infinite nest detected" if klass == self
      
      klass.configs.each_value do |config|
        if config.kind_of?(Nest)
          check_infinite_nest(config.configurable_class)
        end
      end
    end
  end
end