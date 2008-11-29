class ConfigurationParser 
  class Switch < Option
    attr_reader :negative_long
    
    def initialize(*args)
      super
      @negative_long = long ? ConfigurationParser.longify("no-#{long[2,long.length-2]}") : nil
      
      unless default == true || default == false
        raise ArgumentError, "default value must be boolean"
      end
    end
    
    def switches
      [long, negative_long, short].compact
    end
    
    def parse(switch, value, argv, config)
      raise "value specified for switch" if value
      config[key] = (switch == negative_long ? !default : default)
    end
    
  end
end