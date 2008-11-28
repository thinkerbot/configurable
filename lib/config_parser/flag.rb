class ConfigParser 
  class Flag

    def parse(switch, value, argv, config)
      raise "value specified for flag" if value
      config[key] = !default
    end
    
  end
end