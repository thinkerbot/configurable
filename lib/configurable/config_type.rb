module Configurable
  class ConfigType
    
    attr_reader :caster
    attr_reader :matcher
    
    def initialize(caster, matcher=nil)
      @caster = caster
      @matcher = matcher
    end
    
    def matches?(value)
      matcher && matcher === value
    end
  end
end