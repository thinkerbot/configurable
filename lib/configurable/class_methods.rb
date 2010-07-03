require 'configurable/config_hash'
require 'configurable/options'

autoload(:ConfigParser, 'config_parser')

module Configurable
  
  # ClassMethods extends classes that include Configurable and provides methods
  # for declaring configurations.
  module ClassMethods
    # A hash of (key, Config) pairs tracking configs defined on self.  See
    # configurations for all configs declared across all ancestors.
    attr_reader :config_registry
    
    attr_reader :opts
    
    def self.initialize(base)  # :nodoc:
      unless base.instance_variable_defined?(:@config_registry)
        base.instance_variable_set(:@config_registry, {})
      end
      
      unless base.instance_variable_defined?(:@configurations)
        base.instance_variable_set(:@configurations, nil)
      end
      
      unless base.instance_variable_defined?(:@opts)
        base.instance_variable_set(:@opts, Options.new)
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
    # generated on each call to ensure it accurately reflects any configs
    # added on ancestors. This slows down initialization and config access
    # through instance.config.
    #
    # Call cache_configurations after all configs have been declared in order
    # to prevent regeneration of configurations and to significantly improve
    # performance.
    def configurations
      return @configurations if @configurations
      
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
    
    # Caches the configurations hash so as to improve peformance.  Call
    # with on set to false to turn off caching.
    def cache_configurations(on=true)
      @configurations = nil
      @configurations = self.configurations if on
    end
    
    protected
    
    def config(name, default=nil, options=opts.guess(default))
      options = {
        :class => Config,
        :desc  => Lazydoc.register_caller(Lazydoc::Trailer)
      }.merge(options)
      
      config_class = options[:class] or raise("no config class specified: #{options.inspect}")
      
      config = config_class.new(name, default, options)
      config_registry[name] = config
      
      config.define_reader(self) unless options[:reader]
      config.define_writer(self) unless options[:writer]
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
      cache_configurations(@configurations != nil)
      
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
      # temporarily cache as an optimization
      configs = configurations
      unless configs.has_key?(name)
        raise NameError.new("#{name.inspect} is not a config on #{self}")
      end
      
      options = {
        :reader => true,
        :writer => true
      }.merge(options)
      
      config = configs[name]
      config_registry[name] = nil
      cache_configurations(@configurations != nil)
      
      undef_method(config.reader) if options[:reader]
      undef_method(config.writer) if options[:writer]
    end

    private
    
    def inherited(base) # :nodoc:
     ClassMethods.initialize(base)
     super
    end
    
    # helper to recursively check for an infinite nest
    def check_infinite_nest(klass) # :nodoc:
      raise "infinite nest detected" if klass == self
      
      klass.configurations.each_value do |config|
        if config.kind_of?(NestConfig)
          check_infinite_nest(config.nest_class)
        end
      end
    end
  end
end