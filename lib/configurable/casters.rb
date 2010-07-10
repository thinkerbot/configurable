module Configurable
  module Casters
    module_function
    
    def cast_boolean(input)
      case input
      when true, false then input
      when 'true'      then true
      when 'false'     then false
      else raise ArgumentError, "invalid value for boolean: #{input.inspect}"
      end
    end
    alias cast_flag cast_boolean
    alias cast_switch cast_boolean
    
    def cast_integer(input)
      Integer(input)
    end
    
    def cast_float(input)
      Float(input)
    end
    
    def cast_string(input)
      input.to_s
    end
  end
end