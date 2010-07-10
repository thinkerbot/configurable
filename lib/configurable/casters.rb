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
    
    def cast_string(input)
      input.to_s
    end
  end
end