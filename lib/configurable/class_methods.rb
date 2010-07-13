require 'lazydoc'
require 'configurable/config'
require 'configurable/config_type'
require 'configurable/config_hash'
require 'configurable/nest'

autoload(:ConfigParser, 'config_parser')

module Configurable
  DEFAULT_CONFIG_TYPES = {
    :flag    => ConfigType.new(:cast_boolean, FalseClass),
    :switch  => ConfigType.new(:cast_boolean, TrueClass),
    :integer => ConfigType.new(:Integer, Integer),
    :float   => ConfigType.new(:Float, Float),
    :string  => ConfigType.new(:cast_string, String),
    nil      => ConfigType.new(nil)
  }
  
  # ClassMethods extends classes that include Configurable and provides methods
  # for declaring configurations.
  module ClassMethods
    # A hash of (key, Config) pairs tracking configs defined on self.  See
    # configurations for all configs declared across all ancestors.
    attr_reader :config_registry
    
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
    def parse(argv=ARGV, options={}) # :yields: parser
      parse!(argv.dup, options)
    end
    
    # Same as parse, but removes parsed args from argv.
    def parse!(argv=ARGV, options={})
      parser = ConfigParser.new
      parser.add(configurations)
      
      args = parser.parse!(argv, options)
      [args, parser.config]
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
    
    def reset_config_types
      @config_types = nil
    end
    
    protected
    
    def config(name, default=nil, attrs={})
      attrs[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      attrs[:type] ||= guess_type(default)
      attrs[:list] ||= default.kind_of?(Array)
      
      reader  = attrs.delete(:reader)
      writer  = attrs.delete(:writer)
      
      config = Config.new(name, default, reader, writer, attrs)
      config_registry[config.name] = config
      reset_configurations
      
      define_config_reader(config) unless reader
      define_config_writer(config) unless writer
      
      config
    end
    
    def nest(name, options={}, &block)
      options = {:class => options} unless options.kind_of?(Hash)
      options[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      
      reader = options.delete(:reader)
      writer = options.delete(:writer)
      configurable_class = options.delete(:class)
      const_name = options.delete(:const_name) || name.to_s.capitalize
      
      # define the configurable class
      if configurable_class.nil?
        configurable_class = Class.new { include Configurable }
      elsif block_given?
        configurable_class = Class.new(configurable_class)
      end
      clean_const_set(configurable_class, const_name)
      configurable_class.class_eval(&block) if block_given?
      check_infinite_nest(configurable_class)
      
      nest = Nest.new(name, configurable_class, reader, writer, options)
      config_registry[nest.name] = nest
      reset_configurations
      
      define_config_reader(nest) unless reader
      define_nest_writer(nest) unless writer
      
      nest
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
      
      undef_method(config.reader) if options[:reader]
      undef_method(config.writer) if options[:writer]
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
      
      undef_method(config_type.caster) if options[:caster]
      config_type
    end
    
    def undef_config_type(type, options={})
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
    
    def define_config_reader(config) # :nodoc:
      name = config.name
      
      line = __LINE__ + 1
      class_eval %Q{
        attr_reader :#{name}
        public :#{name}
      }, __FILE__, line
    end
    
    def define_config_writer(config)
      name   = config.name
      list   = config[:list]
      type   = config_types[config[:type]]
      caster = type ? type.caster : nil
      options_const = options_const_set(name, config[:options])
      
      case
      when list && options_const
        define_list_select_writer(name, caster, options_const)
      when options_const
        define_select_writer(name, caster, options_const)
      when list
        define_list_writer(name, caster)
      else
        define_default_writer(name, caster)
      end
    end
    
    def define_default_writer(name, caster=nil) # :nodoc:
      line = __LINE__ + 1
      class_eval %Q{
        def #{name}=(value)
          @#{name} = #{caster}(value)
        end
        public :#{name}=
      }, __FILE__, line
    end
    
    def define_list_writer(name, caster) # :nodoc:
      line = __LINE__ + 1
      class_eval %Q{
        def #{name}=(values)
          unless values.kind_of?(Array)
            raise ArgumentError, "invalid value for #{name}: \#{values.inspect}"
          end

          values.collect! {|value| #{caster}(value) }
          @#{name} = values
        end
        public :#{name}=
      }, __FILE__, line
    end
    
    def define_select_writer(name, caster, options_const) # :nodoc:
      line = __LINE__ + 1
      class_eval %Q{
        def #{name}=(value)
          value = #{caster}(value)
          unless #{options_const}.include?(value)
            raise ArgumentError, "invalid value for #{name}: \#{value.inspect}"
          end
          @#{name} = value
        end
        public :#{name}=
      }, __FILE__, line
    end
    
    def define_list_select_writer(name, caster, options_const) # :nodoc:
      line = __LINE__ + 1
      class_eval %Q{
        def #{name}=(values)
          unless values.kind_of?(Array)
            raise ArgumentError, "invalid value for #{name}: \#{values.inspect}"
          end

          values.collect! {|value| #{caster}(value) }

          unless values.all? {|value| #{options_const}.include?(value) }
            raise ArgumentError, "invalid value for #{name}: \#{values.inspect}"
          end

          @#{name} = values
        end
        public :#{name}=
      }, __FILE__, line
    end
    
    def define_nest_writer(config) # :nodoc:
      name = config.name
      configurable_class = config.configurable_class
      
      line = __LINE__ + 1
      class_eval %Q{
        def #{name}=(value)
          unless value.kind_of?(#{configurable_class})
            raise ArgumentError, "invalid value for #{name}: \#{value.inspect}"
          end
          
          @#{name} = value
        end
        public :#{name}=
      }, __FILE__, line
    end
    
    def guess_type(value) # :nodoc:
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
    
    def clean_const_set(const, const_name) # :nodoc:
      return nil unless const_name
      
      unless const_defined?(const_name) && const_get(const_name) == const
        const_set(const_name, const)
      end
    end
    
    def options_const_set(name, options) # :nodoc:
      return nil unless options
      
      options_const = "#{name.to_s.upcase}_OPTIONS"
      clean_const_set(options, options_const)
      options_const
    end
    
    # helper to recursively check for an infinite nest
    def check_infinite_nest(klass) # :nodoc:
      raise "infinite nest detected" if klass == self
      
      klass.configurations.each_value do |config|
        if config.kind_of?(Nest)
          check_infinite_nest(config.configurable_class)
        end
      end
    end
  end
end