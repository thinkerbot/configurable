module Configurable
  class ConfigType
    class << self
      def cast_boolean(input)
        case input
        when true, false then input
        when 'true'      then true
        when 'false'     then false
        else raise ArgumentError, "invalid value for boolean: #{input.inspect}"
        end
      end
    end
    
    attr_reader :matcher
    attr_reader :caster
    
    def initialize(matcher=nil, &caster)
      @matcher = matcher
      @caster = caster
    end
    
    def ===(value)
      matcher && matcher === value
    end
  end
end