module Configurable
  class ConfigType
    attr_reader :caster
    attr_reader :matcher
    attr_reader :default_attrs
    
    def initialize(caster, matcher=nil, default_attrs={})
      @caster = caster
      @matcher = matcher
      @default_attrs = default_attrs
    end
    
    def matches?(value)
      matcher && matcher === value
    end
  end
end