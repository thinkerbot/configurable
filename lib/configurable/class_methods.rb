require 'lazydoc'
require 'config_parser'
require 'configurable/caster'
require 'configurable/configs'
require 'configurable/config_hash'

module Configurable
  DEFAULT_CASTERS = {
    :flag    => Caster.new(FalseClass) {|value| Caster.cast_to_bool(value) },
    :switch  => Caster.new(TrueClass)  {|value| Caster.cast_to_bool(value) },
    :integer => Caster.new(Integer) {|value| Integer(value) },
    :float   => Caster.new(Float)   {|value| Float(value) },
    :string  => Caster.new(String)  {|value| String(value) }
  }
  
  # ClassMethods extends classes that include Configurable and provides methods
  # for declaring configurations.
  module ClassMethods
    # A hash of (key, Config) pairs tracking configs defined on self.  See the
    # configs method for all configs declared across all ancestors.
    attr_reader :config_registry
    
    # A hash of (key, Caster) pairs tracking casters defined on self.  See the
    # casters method for all casters declared across all ancestors.
    attr_reader :caster_registry
    
    def self.initialize(base)  # :nodoc:
      base.reset_configs
      unless base.instance_variable_defined?(:@config_registry)
        base.instance_variable_set(:@config_registry, {})
      end
      
      base.reset_casters
      unless base.instance_variable_defined?(:@caster_registry)
        base.instance_variable_set(:@caster_registry, {})
      end
    end
    
    # Parses configs from argv in a non-destructive manner by generating a
    # ConfigParser using the configs for self.  Returns an array like
    # [args, config] where the args are the arguments that remain after
    # parsing, and config is a hash of the parsed configs. The parser is
    # yielded to the block, if given, to register additonal options.  
    #
    # See ConfigParser#parse for more information.
    def parse(argv=ARGV, options={}, &block) # :yields: parser
      parse!(argv.dup, options, &block)
    end
    
    # Same as parse, but removes parsed args from argv.
    def parse!(argv=ARGV, options={})
      parser = ConfigParser.new({}, options)
      
      configs.each_value do |config|
        parser.add(config.key, config.default, config.attrs)
      end
      
      yield(parser) if block_given?
      
      parser.sort_opts!
      [parser.parse!(argv), parser.config]
    end
    
    def cast(argh={})
      argh.keys.each do |key|
        if config = configs[key]
          argh[key] = config.cast(configs[key])
        end
      end
      
      argh
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
    
    # A hash of (key, Caster) pairs representing all casters defined on this
    # class or inherited from ancestors.  The casters hash is memoized for
    # performance.  Call reset_casters if casters needs to be recalculated for
    # any reason.
    def casters
      @casters ||= begin
        casters = Configurable::DEFAULT_CASTERS.dup
      
        ancestors.reverse.each do |ancestor|
          next unless ancestor.kind_of?(ClassMethods)
          ancestor.caster_registry.each_pair do |key, value|
            if value.nil?
              casters.delete(key)
            else
              casters[key] = value
            end
          end
        end
      
        casters
      end
    end
    
    # Resets casters such that they will be recalculated.
    def reset_casters
      @casters = nil
    end
    
    protected
    
    # Defines and registers an instance of config_class with the specified key
    # and attrs.  Unless attrs specifies a :reader or :writer, an attr_reader
    # and attr_writer will be defined for the config name (which by default is
    # the key). Also resolves a caster from the :caster attribute.
    def define_config(key, attrs={}, config_class=Config)
      reader = attrs[:reader]
      writer = attrs[:writer]
      caster = attrs[:caster]
      
      if caster = casters[caster]
        attrs[:caster] = caster
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
      
      if caster && attrs.has_key?(:caster)
        raise "please specify only a caster block or the :caster option"
      end
      
      unless attrs.has_key?(:caster)
        attrs[:caster] = caster || guess_caster_type(default)
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
    
    def caster(type, matcher=nil, &block)
      caster = Caster.new(matcher, &block)
      caster_registry[type] = caster
      reset_casters
      
      caster
    end
    
    def remove_caster(type)
      unless caster_registry.has_key?(type)
        raise NameError.new("#{type.inspect} is not a caster on #{self}")
      end
      
      caster = caster_registry.delete(type)
      reset_casters
      caster
    end
    
    def undef_caster(type)
      unless casters.has_key?(type)
        raise NameError.new("#{type.inspect} is not a caster on #{self}")
      end
      
      caster = caster_registry[type]
      caster_registry[type] = nil
      reset_casters
      caster
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
    
    def guess_caster_type(value) # :nodoc:
      guess_value = value.kind_of?(Array) ? value.first : value
      
      guesses = []
      casters.each_pair do |type, caster|
        if caster === guess_value
          guesses << type
        end
      end
      
      if guesses.length > 1
        raise "multiple guesses for caster type: #{value.inspect} #{guesses.inspect}"
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