class ConfigParser 
  class Switch
    # long to --[no-]switch
    # corresponding value: --switch    => default
    #                      --no-switch => !default
    attr_reader :negative_long
    
    def initialize
      super
      @negative_long = longify("no-#{long}")
    end
    
    def switches
      super + [negative_long]
    end
    
    def parse(switch, value, argv, config)
      raise "value specified for switch" if value
      config[key] = (switch == negative_long ? !default : default)
    end
    
  end
end