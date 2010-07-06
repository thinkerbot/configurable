module Configurable
  module Caster
    module_function
    
    DEFAULTS = {
      TrueClass  => "#{self}.cast_boolean",
      FalseClass => "#{self}.cast_boolean",
      Integer    => Integer,
      Float      => Float,
      String     => nil
    }
    
    def cast_boolean(input)
      case input
      when true, false then input
      when 'true'      then true
      when 'false'     then false
      else raise ArgumentError, "invalid boolean value: #{input.inspect}"
      end
    end
  end
end