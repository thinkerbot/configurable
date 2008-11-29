class ConfigurationParser 
  class Flag < Option
    
    def initialize(*args)
      super
      unless default == true || default == false
        raise ArgumentError, "default value must be boolean"
      end
    end
    
    def parse(switch, value, argv, config)
      raise "value specified for flag" if value
      config[key] = !default
    end
    
  end
end