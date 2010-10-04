module Configurable
  class Caster
    class << self
      def cast_to_bool(input)
        case input
        when true, false then input
        when 'true'      then true
        when 'false'     then false
        else raise ArgumentError, "invalid value for boolean: #{input.inspect}"
        end
      end
    end
    
    attr_reader :matcher
    
    def initialize(matcher=nil, &block)
      @matcher = matcher
      @block = block
    end
    
    def call(value)
      @block ? @block.call(value) : value
    end
    
    def ===(value)
      matcher && matcher === value
    end
  end
end