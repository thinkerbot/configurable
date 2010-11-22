require 'lazydoc'
require 'configurable/config_classes'
require 'configurable/config_hash'
require 'configurable/conversions'

module Configurable
  
  # Hash of default config types (bool, integer, float, string).
  DEFAULT_CONFIG_TYPES = {
    :bool    => ConfigClasses::BooleanConfig,
    :integer => ConfigClasses::IntegerConfig,
    :float   => ConfigClasses::FloatConfig,
    :string  => ConfigClasses::StringConfig,
    :nest    => ConfigClasses::NestConfig,
    :obj     => ConfigClasses::ObjectConfig
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
    def define_config(key, attrs={}, config_class=ObjectConfig)
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
    def config(key, default=nil, attrs={}, &block)
      nest_class = guess_nest_class(default, block)
      
      attrs[:default] = nest_class ? nest_class.new : default
      attrs[:desc]    = guess_config_desc(attrs, Lazydoc.register_caller)
      attrs[:list]    = default.kind_of?(Array) unless attrs.has_key?(:list)
      
      config_class = guess_config_type(attrs)
      config = define_config(key, attrs, config_class)
      
      if attrs[:list]
        config.extend List
      end
      
      if nest_class
        const_name = attrs[:const_name] || guess_nest_const_name(config)
        unless const_defined?(const_name)
          const_set(const_name, nest_class)
        end
      end

      config
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
    
    def define_config_type(name, config_type)
      config_type_registry[name] = config_type
      reset_config_types
      config_type
    end
    
    def config_type(name, *matchers, &caster)
      config_type = StringConfig.subclass(*matchers).cast(&caster)
      const_name  = guess_config_type_const_name(name)
      
      unless const_defined?(const_name)
        const_set(const_name, config_type)
      end
      
      define_config_type(name, config_type)
    end
    
    # Removes a config_type much like remove_method removes a method.
    def remove_config_type(name)
      unless config_type_registry.has_key?(name)
        raise NameError.new("#{name.inspect} is not a config_type on #{self}")
      end
      
      config_type = config_type_registry.delete(name)
      reset_config_types
      config_type
    end
    
    # Undefines a config_type much like undef_method undefines a method.
    #
    # ==== Implementation Note
    #
    # ConfigClasses are undefined by setting the key to nil in the registry.
    # Deleting the config_type is not sufficient because the registry needs to
    # convey to self and subclasses to not inherit the config_type from
    # ancestors.
    #
    # This is unlike remove_config_type where the config_type is simply
    # deleted from the config_type_registry.
    def undef_config_type(name)
      unless config_types.has_key?(name)
        raise NameError.new("#{name.inspect} is not a config_type on #{self}")
      end
      
      config_type = config_type_registry[name]
      config_type_registry[name] = nil
      reset_config_types
      config_type
    end
    
    private
    
    def inherited(base) # :nodoc:
      ClassMethods.initialize(base)
      super
    end

    def guess_nest_class(base, block) # :nodoc:
      unless base.kind_of?(Hash) || block
        return nil
      end

      nest_class = base.kind_of?(Class) ? 
        Class.new(base) :
        Class.new { include Configurable }

      if base.kind_of?(Hash)
        base.each_pair do |key, value|
          nest_class.send(:config, key, value)
        end
      end

      if block
        nest_class.class_eval(&block)
      end

      check_infinite_nest(nest_class)
      nest_class
    end

    # helper to recursively check for an infinite nest
    def check_infinite_nest(klass) # :nodoc:
      raise "infinite nest detected" if klass == self

      klass.configs.each_value do |config|
        if config.kind_of?(NestConfig)
          check_infinite_nest(config.configurable.class)
        end
      end
    end
    
    def each_registry # :nodoc:
      ancestors.each do |ancestor|
        case 
        when ancestor.kind_of?(ClassMethods)
          yield ancestor, ancestor.config_type_registry
          
        when ancestor == Configurable
          yield ancestor, Configurable::DEFAULT_CONFIG_TYPES
          break
          
        else next
        end
      end
    end
    
    def guess_config_type_by_name(name) # :nodoc:
      return name if name.nil?
      
      each_registry do |ancestor, registry|
        if registry.has_key?(name)
          return registry[name]
        end
      end
      
      raise "no such config type: #{type.inspect}"
    end
    
    def guess_config_type_by_value(value) # :nodoc:
      each_registry do |ancestor, registry|
        guesses = registry.values.select {|config_type| config_type.matches?(value) }
        
        case guesses.length
        when 0 then next
        when 1 then return guesses.at(0)
        else raise "multiple guesses for config type: #{guesses.inspect} (in: #{ancestor} default: #{default.inspect})"
        end
      end
      
      ObjectConfig
    end
    
    def guess_config_type(attrs) # :nodoc:
      if attrs.has_key?(:type)
        guess_config_type_by_name attrs[:type]
      else
        value = attrs[:default]
        value = value.at(0) if value.kind_of?(Array)
        guess_config_type_by_value value
      end
    end
    
    def guess_config_desc(base_attrs, comment) # :nodoc:
      Hash.new do |hash, key|
        comment.resolve
        
        if trailer = comment.trailer
          flags, desc = trailer.split(':', 2)
          flags, desc = '', flags unless desc
        
          argv = flags.split(',').collect! {|arg| arg.strip }
          argv << desc
        
          comment_attrs = ConfigParser::Utils.parse_attrs(argv)
          comment_attrs.each_pair do |attr_key, attr_value|
            unless hash.has_key?(attr_key)
              hash[attr_key] = attr_value
            end
          end
        end
        
        unless hash.has_key?(:help)
          hash[:help] = comment.content
        end
        
        hash.has_key?(key) ? hash[key] : nil
      end.merge!(base_attrs)
    end
    
    def guess_nest_const_name(config) # :nodoc:
      config.name.gsub(/(?:^|_)(.)/) { $1.upcase }
    end
    
    def guess_config_type_const_name(name) # :nodoc:
      "#{name}Type".gsub(/(?:^|_)(.)/) { $1.upcase }
    end
  end
end