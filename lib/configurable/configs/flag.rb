require 'configurable/config'

module Configurable
  module Configs
    class Flag < Config
      @pattern = FalseClass
      
      def self.caster
        "#{self}.cast"
      end
      
      def self.cast(input)
        case input
        when true, false then input
        when 'true'      then true
        when 'false'     then false
        else raise ArgumentError, "invalid value for boolean: #{input.inspect}"
        end
      end
    end
  end
end