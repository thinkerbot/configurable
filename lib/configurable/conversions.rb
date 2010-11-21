require 'config_parser'
require 'configurable/config_classes'

module Configurable
  
  # A set of methods used to convert various inputs based on a hash of (key,
  # Config) pairs.  Extend the hash and then use the methods.
  module Conversions
    
    # Initializes and returns a ConfigParser generated using the configs for
    # self.  Arguments given to parser are passed to the ConfigParser
    # initializer.
    def to_parser(*args, &block)
      parser = ConfigParser.new(*args, &block)
      traverse do |nesting, config|
        next if config[:hidden] == true || nesting.any? {|nest| nest[:hidden] == true }
        
        nest_keys  = nesting.collect {|nest| nest.key }
        nest_names = nesting.collect {|nest| nest.name }.push(config.name)

        guess_attrs = {
          :long      => nest_names.join(':'),
          :hint      => guess_hint(config)
        }
        
        config_attrs = {
          :key       => config.key, 
          :nest_keys => nest_keys,
          :default   => config.default,
          :callback  => lambda {|value| config.type.cast(value) }
        }
        
        attrs = guess_attrs.merge(config.desc).merge(config_attrs)
        parser.on(attrs)
      end
      
      parser.sort_opts!
      parser
    end
    
    # Returns a hash of the default values for each config in self.
    def to_default
      default = {}
      each_pair do |key, config|
        default[key] = config.default
      end
      default
    end
    
    def import(source, target={})
      each_value do |config|
        name = config.name
        
        if source.has_key?(name)
          target[config.key] = config.cast(source[name])
        end
      end
      
      target
    end
    
    def export(source, target={})
      each_value do |config|
        key = config.key
        
        if source.has_key?(key)
          target[config.name] = config.uncast(source[key])
        end
      end
      
      target
    end
    
    # Yields each config in configs to the block with nesting, after appened
    # self to nesting.
    def traverse(nesting=[], &block)
      each_value do |config|
        if config.respond_to?(:configurable)
          nesting.push config
          config.configurable.class.configs.traverse(nesting, &block)
          nesting.pop
        else
          yield(nesting, config)
        end
      end
    end
    
    protected
    
    def guess_hint(config)
      default = config.default
      
      case default
      when true, false, nil
        nil
      when Array
        delimiter = config[:delimiter] || ','
        config.uncast(config.default).join(delimiter)
      else
        default.to_s
      end
    end
  end
end