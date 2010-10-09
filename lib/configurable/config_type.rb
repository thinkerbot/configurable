module Configurable
  class ConfigType
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
    
    attr_reader :matchers
    attr_reader :default_attrs
    
    def initialize(*matchers)
      @matchers = matchers
      @default_attrs = matchers.last.kind_of?(Hash) ? matchers.pop : {}
    end
    
    def cast(&caster)
      @default_attrs[:caster] = caster
      self
    end
    
    def uncast(&uncaster)
      @default_attrs[:uncaster] = uncaster
      self
    end
    
    def ===(value)
      matchers.any? {|matcher| matcher === value }
    end
  end
end