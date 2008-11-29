module Configurable
  class ConfigParser 
    class List < Option
      # list allows to --list a,b,c
      # list generates an array value, always
      # n > 1 concatenates additional values
    
      # number of times option may be specified.
      # n indicates a specification up to n values
      # nil collects all values as a single array
      attr_reader :n
    
      attr_reader :split
    
      #attr_reader :allowed_values  # an optional array of allowed values
    
      def initialize(key, default, options={}, &block)
        super
        @n = options[:n]
        @split = options[:split]
        #@allowed_values = options[:allowed_values]
      end
    
      def parse(switch, value, argv, config)
        value = argv.shift unless value
      
        # if allowed_values
        #   unallowed_values = values - allowed_values
        #   unless unallowed_values.empty?
        #     raise "unallowed values: #{unallowed_values.inpect}"
        #   end
        # end
      
        current = (config[key] ||= [])
        if split
          current.concat(value.split(split))
        else
          current << value
        end
        raise "too many assignments: #{key}" if n && current.length > n
      end
    
      def to_s
        short_str = short ? short + ',' : '   '
        split_str = split ? ['A', 'B', 'C'].join(split) : key.upcase
        "%-40s%-40s" % ["    #{short_str} #{long} #{split_str}", desc]
      end
    end
  end
end