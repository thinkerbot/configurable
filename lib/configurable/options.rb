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
      options
    end
    
    def guess(value)
      guesses = []
      
      registry.each_pair do |type, options|
        if matcher = options[:matches]
          if matcher === value
            guesses << type
          end
        end
      end
      
      case guesses.length
      when 0 then {}
      when 1 then registry[guesses.first]
      else 
        guesses = guesses.sort_by {|guess| guess.to_s }
        raise "multiple guesses for config type: #{value.inspect} #{guesses.inspect}"
      end
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