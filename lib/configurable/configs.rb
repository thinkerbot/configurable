require 'config_parser'
require 'configurable/config_classes'

module Configurable
  class Configs < Hash
    
    # Initializes and returns a ConfigParser generated using the configs for
    # self.  Arguments given to parser are passed to the ConfigParser
    # initializer.  The parser is yielded to the block, if given, to register
    # additonal options and then the options are sorted.
    def to_parser(*args)
      parser = ConfigParser.new(*args)
      each_value do |config|
        config.traverse do |nesting, config|
          next if config[:hidden] == true || nesting.any? {|nest| nest[:hidden] == true }
          
          key = config.key
          nest_keys = nesting.collect {|nest| nest.key }
          nest_names = nesting.collect {|nest| nest.name }.push(config.name)
          
          attrs = {
            :key => key, 
            :nest_keys => nest_keys,
            :long => nest_names.join(':')
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
    
    # Writes the value keyed by key to name for each config in source to
    # target, recursively for nested configs.  Returns target.
    def keyify(source, target={})
      each_value do |config|
        config.keyify(source, target)
      end
      target
    end
    
    # Writes the value keyed by name to key for each config in source to
    # target, recursively for nested configs.  Returns target.
    def nameify(source, target={})
      each_value do |config|
        config.nameify(source, target)
      end
      target
    end
    
    # Casts each config in source and writes the result into target (which is
    # by default the source itself).  ConfigClasses are identifies and written by
    # key.  Returns target.
    def cast(source, target=source)
      source.keys.each do |key|
        if config = self[key]
          target[key] = config.cast(source[key])
        end
      end
      
      target
    end
    
    def uncast(source, target=source)
      source.keys.each do |key|
        if config = self[key]
          target[key] = config.uncast(source[key])
        end
      end
      
      target
    end
    
    def import(source, target=source)
      keyify(source, target)
      cast(target)
    end
    
    def export(source, target=source)
      uncast(source, target)
      nameify(target)
    end
    
    def traverse(nesting=[], &block)
      each_value do |config|
        config.traverse(nesting, &block)
      end
      self
    end
  end
end