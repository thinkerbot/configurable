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
        hint = guess_hint(config)
        
        attrs = {
          :key       => config.key, 
          :nest_keys => nest_keys,
          :long      => nest_names.join(':'),
          :hint      => hint,
          :callback  => config.caster
        }
        
        parser.on(attrs.merge(config.attrs))
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
    
    # Import (ie map names to keys and cast values) from source to target.
    def import(source, target={}, &block)
      each_value do |config|
        config.import(source, target, &block)
      end
      target
    end
    
    # Export (ie map keys to names and uncast values) from source to target.
    def export(source, target={}, &block)
      each_value do |config|
        config.export(source, target, &block)
      end
      target
    end
    
    # Yields each config in configs to the block with nesting, after appened
    # self to nesting.
    def traverse(nesting=[], &block)
      each_value do |config|
        if config.respond_to?(:configs)
          nesting.push config
          config.configs.traverse(nesting, &block)
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