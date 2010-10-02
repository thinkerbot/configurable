require 'lazydoc'
require 'config_parser'
require 'configurable/configs'
require 'configurable/config_type'
require 'configurable/config_hash'

module Configurable
  DEFAULT_CONFIG_TYPES = {
    :flag    => ConfigType.new(:cast_boolean, FalseClass),
    :switch  => ConfigType.new(:cast_boolean, TrueClass),
    :integer => ConfigType.new(:Integer, Integer),
    :float   => ConfigType.new(:Float, Float),
    :string  => ConfigType.new(:cast_string, String),
    :nest    => ConfigType.new(nil),
    nil      => ConfigType.new(nil)
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
    
    def define_config(name, options={})
      default = options.delete(:default)
      reader  = options.delete(:reader)
      writer  = options.delete(:writer)
      attrs   = options[:attrs] || options
      
      config_class = options.delete(:config_class) || guess_config_class(attrs)
      config = config_class.new(name, default, reader, writer, attrs)
      
      unless reader
        config.define_default_reader(self)
      end
      
      unless writer
        config_type = config_types[attrs[:type]]
        config.define_default_writer(self, config_type ? config_type.caster : nil)
      end
      
      config_registry[name] = config
      reset_configurations
      config
    end
    
    def config(name, default=nil, options={})
      options[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      options[:type] ||= guess_config_type(default)
      options[:list] ||= default.kind_of?(Array)
      options[:default] = default
      
      define_config(name, options)
    end
    
    def nest(name, options={}, &block)
      options = {:class => options} unless options.kind_of?(Hash)
      options[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      options[:type] ||= :nest
      options[:config_class] ||= Configs::Nest
      
      base_class = options.delete(:class)
      const_name = options.delete(:const_name) || name.to_s.capitalize
      
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
      
      options[:default] = configurable_class
      define_config(name, options)
    end
    
    # Removes a configuration much like remove_method removes a method.  The
    # reader and writer for the config are likewise removed.  Nested configs
    # can be removed using this method.
    #
    # Setting :reader or :writer to false in the options prevents those methods
    # from being removed.
    #
    def remove_config(name, options={})
      unless config_registry.has_key?(name)
        raise NameError.new("#{name.inspect} is not a config on #{self}")
      end
      
      options = {
        :reader => true,
        :writer => true
      }.merge(options)
      
      config = config_registry.delete(name)
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
    def undef_config(name, options={})
      unless configurations.has_key?(name)
        raise NameError.new("#{name.inspect} is not a config on #{self}")
      end
      
      options = {
        :reader => true,
        :writer => true
      }.merge(options)
      
      config = configurations[name]
      config_registry[name] = nil
      reset_configurations
      
      undef_method(config.reader) if options[:reader]
      undef_method(config.writer) if options[:writer]
      
      config
    end
    
    def config_type(type, options={}, &block)
      caster  = options[:caster] || "cast_#{type}".to_sym
      matcher = options[:matcher]
      
      if block_given?
        define_method(caster, &block)
      end
      
      config_type = ConfigType.new(caster, matcher)
      config_types_registry[type.to_sym] = config_type
      reset_config_types
      
      config_type
    end
    
    def remove_config_type(type, options={})
      unless config_types.has_key?(type)
        raise NameError.new("#{type.inspect} is not a config type on #{self}")
      end
      
      options = {
        :caster => true
      }.merge(options)
      
      config_type = config_type_registry.delete(type)
      reset_config_types
      
      remove_method(config_type.caster) if options[:caster]
      config_type
    end
    
    def undef_config_type(type)
      unless config_types.has_key?(type)
        raise NameError.new("#{type.inspect} is not a config type on #{self}")
      end
      
      options = {
        :caster => true
      }.merge(options)
      
      config_type = config_type_registry[type]
      config_type_registry[type] = nil
      reset_config_types
      
      undef_method(config_type.caster) if options[:caster]
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
    
    def guess_config_type(value) # :nodoc:
      guess_value = value.kind_of?(Array) ? value.first : value
      
      guesses = []
      config_types.each_pair do |type, config_type|
        if config_type.matches?(guess_value)
          guesses << type
        end
      end
      
      if guesses.length > 1
        guesses = guesses.sort_by {|type| type.to_s }
        raise "multiple guesses for type: #{value.inspect} #{guesses.inspect}"
      end
      
      guesses.first
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