require 'lazydoc'
require 'config_parser'
require 'configurable/configs'
require 'configurable/config_type'
require 'configurable/config_hash'

module Configurable
  DEFAULT_CONFIG_TYPES = {
    :flag    => ConfigType.new(FalseClass) {|value| ConfigType.cast_boolean(value) },
    :switch  => ConfigType.new(TrueClass)  {|value| ConfigType.cast_boolean(value) },
    :integer => ConfigType.new(Integer) {|value| Integer(value) },
    :float   => ConfigType.new(Float)   {|value| Float(value) },
    :string  => ConfigType.new(String)  {|value| String(value) },
    :nest    => ConfigType.new
  }
  
  # ClassMethods extends classes that include Configurable and provides methods
  # for declaring configurations.
  module ClassMethods
    # A hash of (key, Config) pairs tracking configs defined on self.  See
    # configurations for all configs declared across all ancestors.
    attr_reader :config_registry
    
    # A hash of (key, ConfigType) pairs tracking configuration types defined
    # on self.  See config_types for all configuration types declared across
    # all ancestors.
    attr_reader :config_types_registry
    
    def self.initialize(base)  # :nodoc:
      base.reset_configurations
      unless base.instance_variable_defined?(:@config_registry)
        base.instance_variable_set(:@config_registry, {})
      end
      
      base.reset_config_types
      unless base.instance_variable_defined?(:@config_types_registry)
        base.instance_variable_set(:@config_types_registry, {})
      end
    end
    
    # Parses configurations from argv in a non-destructive manner by generating
    # a ConfigParser using the configurations for self.  Returns an array like
    # [args, config] where the args are the arguments that remain after parsing,
    # and config is a hash of the parsed configs. The parser is yielded to
    # the block, if given, to register additonal options.  
    #
    # See ConfigParser#parse for more information.
    def parse(argv=ARGV, options={}, &block) # :yields: parser
      parse!(argv.dup, options, &block)
    end
    
    # Same as parse, but removes parsed args from argv.
    def parse!(argv=ARGV, options={})
      parser = ConfigParser.new({}, options)
      
      configurations.each_value do |config|
        parser.add(config.name, config.default, config.attrs)
      end
      
      yield(parser) if block_given?
      
      parser.sort_opts!
      [parser.parse!(argv), parser.config]
    end
    
    def cast(configs={})
      configs.keys.each do |key|
        if config = configurations[key]
          configs[key] = config.cast(configs[key])
        end
      end
      
      configs
    end
    
    # A hash of (key, Config) pairs representing all configurations defined
    # on this class or inherited from ancestors.  The configurations hash is
    # memoized for performance.  Call reset_configurations if configurations
    # needs to be recalculated for any reason.
    def configurations
      @configurations ||= begin
        configurations = {}
      
        ancestors.reverse.each do |ancestor|
          next unless ancestor.kind_of?(ClassMethods)
          ancestor.config_registry.each_pair do |key, value|
            if value.nil?
              configurations.delete(key)
            else
              configurations[key] = value
            end
          end
        end
        
        reset_config_types
        configurations
      end
    end
    
    # Resets configurations such that they will be recalculated.
    def reset_configurations
      @configurations = nil
    end
    
    # A hash of (key, ConfigType) pairs representing all configuration types
    # defined on this class or inherited from ancestors.  The config_types
    # hash is memoized for performance.  Call reset_config_types if
    # config_types needs to be recalculated for any reason.
    def config_types
      @config_types ||= begin
        config_types = Configurable::DEFAULT_CONFIG_TYPES.dup
      
        ancestors.reverse.each do |ancestor|
          next unless ancestor.kind_of?(ClassMethods)
          ancestor.config_types_registry.each_pair do |key, value|
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
    
    def define_config(key, attrs={}, config_class=Config)
      reader = attrs[:reader]
      writer = attrs[:writer]
      
      config = config_class.new(key, attrs)
      
      attr_reader(config.name) unless reader
      attr_writer(config.name) unless writer
      
      config_registry[config.key] = config
      reset_configurations
      config
    end
    
    def config(key, default=nil, attrs={}, &caster)
      if caster && attrs.has_key?(:caster)
        raise "please specify only a caster block or the :caster option"
      end
      
      attrs[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      attrs[:list] ||= default.kind_of?(Array)
      attrs[:caster] ||= (caster || guess_caster(default))
      attrs[:default] = default
      
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
    
    # Removes a configuration much like remove_method removes a method.  The
    # reader and writer for the config are likewise removed.  Nested configs
    # can be removed using this method.
    #
    # Setting :reader or :writer to false in the options prevents those methods
    # from being removed.
    #
    def remove_config(key, options={})
      unless config_registry.has_key?(key)
        raise NameError.new("#{key.inspect} is not a config on #{self}")
      end
      
      options = {
        :reader => true,
        :writer => true
      }.merge(options)
      
      config = config_registry.delete(key)
      reset_configurations
      
      remove_method(config.reader) if options[:reader]
      remove_method(config.writer) if options[:writer]
      
      config
    end
    
    # Undefines a configuration much like undef_method undefines a method.  The
    # reader and writer for the config are likewise undefined.  Nested configs
    # can be undefined using this method.
    #
    # Setting :reader or :writer to false in the options prevents those methods
    # from being undefined.
    #
    # ==== Implementation Note
    #
    # Configurations are undefined by setting the key to nil in the registry.
    # Deleting the config is not sufficient because the registry needs to
    # convey to self and subclasses to not inherit the config from ancestors.
    #
    # This is unlike remove_config where the config is simply deleted from
    # the config_registry.
    #
    def undef_config(key, options={})
      unless configurations.has_key?(key)
        raise NameError.new("#{key.inspect} is not a config on #{self}")
      end
      
      options = {
        :reader => true,
        :writer => true
      }.merge(options)
      
      config = configurations[key]
      config_registry[key] = nil
      reset_configurations
      
      undef_method(config.reader) if options[:reader]
      undef_method(config.writer) if options[:writer]
      
      config
    end
    
    def config_type(type, matcher=nil, &caster)
      config_type = ConfigType.new(matcher, &caster)
      config_types_registry[type.to_sym] = config_type
      reset_config_types
      
      config_type
    end
    
    def remove_config_type(type)
      unless config_types.has_key?(type)
        raise NameError.new("#{type.inspect} is not a config type on #{self}")
      end
      
      config_type = config_type_registry.delete(type)
      reset_config_types
      config_type
    end
    
    def undef_config_type(type)
      unless config_types.has_key?(type)
        raise NameError.new("#{type.inspect} is not a config type on #{self}")
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
    
    def guess_caster(value) # :nodoc:
      guess_value = value.kind_of?(Array) ? value.first : value
      
      guesses = []
      config_types.each_pair do |type, config_type|
        if config_type === guess_value
          guesses << config_type
        end
      end
      
      if guesses.length > 1
        guesses = guesses.sort_by {|type| type.to_s }
        raise "multiple guesses for caster: #{value.inspect} #{guesses.inspect}"
      end
      
      config_type = guesses.first
      config_type.caster
    end
    
    # helper to recursively check for an infinite nest
    def check_infinite_nest(klass) # :nodoc:
      raise "infinite nest detected" if klass == self
      
      klass.configurations.each_value do |config|
        if config.kind_of?(Configs::Nest)
          check_infinite_nest(config.configurable_class)
        end
      end
    end
  end
end