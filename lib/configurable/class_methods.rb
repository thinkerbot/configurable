require 'lazydoc'
require 'configurable/config_hash'
autoload(:ConfigParser, 'config_parser')

module Configurable
  DEFAULT_CONFIG_TYPES = {
    :flag    => Configs::Flag,
    :switch  => Configs::Switch,
    :integer => Configs::Integer,
    :float   => Configs::Float,
    nil      => Config
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
            config_types[key] = value
          end
        end
      
        config_types
      end
    end
    
    def reset_config_types
      @config_types = nil
    end
    
    protected
    
    def config(name, default=nil, options={})
      type = options[:type] ||= guess_type(default)
      config_class = config_types[type] or raise "unknown config type: #{type.inspect}"
      
      options[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      caster = options[:caster] || config_class.caster
      options_const = options_const_set(name, options[:options])
      
      config = config_class.new(name, default, options)
      config_registry[config.name] = config
      reset_configurations
      
      unless options[:reader]
        define_reader(name)
      end
      
      unless options[:writer]
        case
        when config.list? && config.select?
          define_list_select_writer(name, caster, options_const)
        when config.select?
          define_select_writer(name, caster, options_const)
        when config.list?
          define_list_writer(name, caster)
        else
          define_writer(name, caster)
        end 
      end
      
      config
    end
    
    def nest(name, configurable_class=nil, options={}, &block)
      options[:desc] ||= Lazydoc.register_caller(Lazydoc::Trailer)
      
      # define the nested configurable
      if configurable_class
        configurable_class = Class.new(configurable_class) if block_given?
      else
        configurable_class = Class.new { include Configurable }
      end
      
      const_name = options[:const_name] || name.to_s.capitalize
      clean_const_set(configurable_class, const_name)
      
      configurable_class.class_eval(&block) if block_given?
      check_infinite_nest(configurable_class)
      
      # setup the nest config
      config = Configs::Nest.new(name, configurable_class, options)
      config_registry[config.name] = config
      reset_configurations
      
      define_reader(name) unless options[:reader]
      define_nest_writer(name, configurable_class) unless options[:writer]
      
      config
    end
    
    def config_cast(clas, options={}, &block)
      type = options[:type] || clas.to_s.split('::').last.downcase.to_sym
      const_name = options[:const_name] || "#{type.to_s.capitalize}Config"
      
      config_class = Class.new(Config) { match clas }
      clean_const_set(config_class, const_name)
      
      if block_given?
        caster = "cast_#{type}"
        config_class.caster = caster
        define_method(caster, &block)
      end
      
      config_types_registry[type] = config_class
      reset_config_types
      
      config_class
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
    end

    private
    
    def inherited(base) # :nodoc:
      ClassMethods.initialize(base)
      super
    end
    
    def define_reader(name) # :nodoc:
      line = __LINE__ + 1
      class_eval %Q{
        attr_reader :#{name}
        public :#{name}
      }, __FILE__, line
    end
    
    def define_writer(name, caster=nil) # :nodoc:
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
    
    def define_nest_writer(name, configurable_class) # :nodoc:
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
      config_types.each_pair do |type, config_class|
        if config_class.matcher && config_class.matcher === guess_value
          guesses << type
        end
      end
      
      if guesses.length > 1
        guesses = guesses.sort_by {|type| type.to_s }
        raise "multiple guesses for type: #{value.inspect} #{guesses.inspect}"
      end
      
      guesses.first
    end
    
    def options_const_set(name, options) # :nodoc:
      return nil unless options
      
      options_const = "#{name.to_s.upcase}_OPTIONS"
      clean_const_set(options, options_const)
      options_const
    end
    
    def clean_const_set(const, const_name) # :nodoc:
      unless const_defined?(const_name) && const_get(const_name) == const
        const_set(const_name, const)
      end
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