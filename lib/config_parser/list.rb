class ConfigParser 
  class List
    # list allows to --list a,b,c
    # list generates an array value, always
    # n > 1 concatenates additional values
    
    # number of times option may be specified.
    # nil indicates an option may be specified multiple times, each new value overrides the previous
    # 1 indicates a specification up to n times, collected as an array
    # -1 collects all values as a single array
    attr_reader :n
    
    attr_reader :allowed_values  # an optional array of allowed values
    
    def initialize
      super
      @n = options[:n]
      @allowed_values = options[:allowed_values]
    end
    
    def parse(switch, value, argv, config)
      values = (value || argv.shift).split(',')
      
      if allowed_values
        unallowed_values = values - allowed_values
        unless unallowed_values.empty?
          raise "unallowed values: #{unallowed_values.inpect}"
        end
      end
      
      if n == nil
        config[key] = values
      else
        current = (config[key] ||= [])
        current.concat(values)
        raise "too many assignments to #{self}" if n >= 0 && current.length > n
      end
    end
    
    def process(config)
      value = config.has_key?(key) ? config[key] : default
      config[key] = block ? block.call(value) : value
    end
    
  end
end