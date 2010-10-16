require 'config_parser'
require 'configurable/config_classes'

module Configurable
  module Conversions
    
    # Initializes and returns a ConfigParser generated using the configs for
    # self.  Arguments given to parser are passed to the ConfigParser
    # initializer.  The parser is yielded to the block, if given, to register
    # additonal options and then the options are sorted.
    def to_parser(*args)
      parser = ConfigParser.new(*args)
      each_value do |config|
        config.traverse do |nesting, config|
          next if config[:hidden] == true || nesting.any? {|nest| nest[:hidden] == true }
          
          nest_keys  = nesting.collect {|nest| nest.key }
          nest_names = nesting.collect {|nest| nest.name }.push(config.name)
          
          attrs = {
            :key       => config.key, 
            :nest_keys => nest_keys,
            :long      => nest_names.join(':'),
            :callback  => config.caster
          }
          
          parser.on(attrs.merge(config.attrs))
        end
      end
      
      yield(parser) if block_given?
      
      parser.sort_opts!
      parser
    end
    
    def to_default
      default = {}
      each_pair do |key, config|
        default[key] = config.default
      end
      default
    end
    
    def import(source, target={})
      each_value do |config|
        config.import(source, target)
      end
      target
    end
    
    def export(source, target={})
      each_value do |config|
        config.export(source, target)
      end
      target
    end
  end
end