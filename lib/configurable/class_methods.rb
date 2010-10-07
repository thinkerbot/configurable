require 'lazydoc'
require 'config_parser'
require 'configurable/configs'
require 'configurable/config_type'
require 'configurable/config_hash'

module Configurable
  DEFAULT_CONFIG_TYPES = {
    :bool    => ConfigType.new(TrueClass, FalseClass) {|value| ConfigType.cast_to_bool(value) },
    :integer => ConfigType.new(Integer) {|value| Integer(value) },
    :float   => ConfigType.new(Float)   {|value| Float(value) },
    :string  => ConfigType.new(String)  {|value| String(value) }
  }
  
  # ClassMethods extends classes that include Configurable and provides methods
  # for declaring configurations.
  module ClassMethods
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
    
    # Initializes and returns a ConfigParser generated using the configs for
    # self.  Arguments given to parser are passed to the ConfigParser
    # initializer.  The parser is yielded to the block, if given, to register
    # additonal options and then the options are sorted.
    def parser(*args)
      parser = ConfigParser.new(*args)
      
      configs.each_value do |config|
        parser.add(config.key, config.default, config.attrs)
      end
      
      yield(parser) if block_given?
      
      parser.sort_opts!
      parser
    end
    
    # Writes the value keyed by key to name for each config in source to
    # target, recursively for nested configs.  Returns target.
    def map_by_key(source, target={})
      configs.each_value do |config|
        config.map_by_key(source, target)
      end
      target
    end
    
    # Writes the value keyed by name to key for each config in source to
    # target, recursively for nested configs.  Returns target.
    def map_by_name(source, target={})
      configs.each_value do |config|
        config.map_by_name(source, target)
      end
      target
    end
    
    # Casts each config in source and writes the result into target (which is
    # by default the source itself).  Configs are identifies and written by
    # key.  Returns target.
    def cast(source, target=source)
      source.keys.each do |key|
        if config = configs[key]
          target[key] = config.cast(source[key])
        end
      end
      
      target
    end
    
    # A hash of (key, Config) pairs representing all configs defined on this
    # class or inherited from ancestors.  The configs hash is memoized for
    # performance.  Call reset_configs if configs needs to be recalculated for
    # any reason.
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
    # and attrs.  Unless attrs specifies a :reader or :writer, an attr_reader
    # and attr_writer will be defined for the config name (which by default is
    # the key). Also resolves a config_type from the :type attribute.
    def define_config(key, attrs={}, config_class=Config)
      reader = attrs[:reader]
      writer = attrs[:writer]
      type   = attrs[:type]
      
      if config_type = config_types[type]
        attrs = config_type.merge(attrs)
      end
      
      config = config_class.new(key, attrs)
      
      attr_reader(config.name) unless reader
      attr_writer(config.name) unless writer
      
      config_registry[config.key] = config
      reset_configs
      config
    end
    
    def config(key, default=nil, attrs={}, &caster)
      attrs[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      attrs[:list] ||= default.kind_of?(Array)
      attrs[:default] = default
      
      unless caster.nil?
        attrs[:caster] = caster
      end
      
      unless attrs.has_key?(:type)
        attrs[:type] = guess_config_type(attrs)
      end
      
      define_config(key, attrs, guess_config_class(attrs))
    end
    
    def nest(key, options={}, &block)
      options = {:class => options} unless options.kind_of?(Hash)
      attrs = options[:attrs] || options
      attrs[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      
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
      
      attrs[:default] = configurable_class
      define_config(key, options, Configs::Nest)
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
    
    def config_type(type, *matchers, &block)
      config_type = ConfigType.new(*matchers, &block)
      config_type_registry[type] = config_type
      reset_config_types
      
      config_type
    end
    
    def remove_config_type(type)
      unless config_type_registry.has_key?(type)
        raise NameError.new("#{type.inspect} is not a config_type on #{self}")
      end
      
      config_type = config_type_registry.delete(type)
      reset_config_types
      config_type
    end
    
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
      list    = attrs[:list]
      options = attrs[:options]
      
      case
      when list && options then Configs::ListSelect
      when list    then Configs::List
      when options then Configs::Select
      else Config
      end
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
    
    # helper to recursively check for an infinite nest
    def check_infinite_nest(klass) # :nodoc:
      raise "infinite nest detected" if klass == self
      
      klass.configs.each_value do |config|
        if config.kind_of?(Configs::Nest)
          check_infinite_nest(config.configurable_class)
        end
      end
    end
  end
end