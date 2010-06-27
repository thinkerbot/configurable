require 'lazydoc'
require 'configurable/config'

module Configurable
  class Options
    
    attr_reader :registry
    
    def initialize
      @registry = {}
    end
    
    def register(type, options={}, &block)
      options = {:class => Config}.merge!(options)
      
      if block
        caller[0] =~ Lazydoc::CALLER_REGEXP
        file, line = $1, ($2.to_i + 1)
        
        config_class = Class.new(options[:class])
        config_class.send(:define_method, :define_on) do |receiver_class|
          receiver_class.class_eval(block.call(name), file, line)
        end
        
        options[:class] = config_class
      end
      
      registry[type.to_sym] = options
      options[:class]
    end
    
    protected
    
    def method_missing(method_name, *args, &block)
      if registry.has_key?(method_name)
        registry[method_name]
      else
        super
      end
    end
  end
end