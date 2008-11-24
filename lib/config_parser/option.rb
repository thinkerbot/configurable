class ConfigParser 
  class Option
    module Utils
      module_function
      
      # Matches a short option
      SHORT_OPTION = /^-[A-z]$/
      
      # Turns the input string into a short-format option.  Raises
      # an error if the option does not match SHORT_REGEXP.
      #
      #   Configuration.shortify("-o")   # => '-o'
      #   Configuration.shortify(:o)     # => '-o'
      #
      #--
      # raise error if it is not A-z
      def shortify(str)
        str = str.to_s
        str = "-#{str}" unless str[0] == ?-
        raise "invalid short option: #{str}" unless str =~ SHORT_OPTION
        str
      end
      
      # Matches a long option
      LONG_OPTION = /^--(\[no-\])?([A-z][\w-]*)$/
      
      # Turns the input string into a long-format option.  Raises
      # an error if the option does not match LONG_REGEXP.
      #
      #   Configuration.longify("--opt")                     # => '--opt'
      #   Configuration.longify(:opt)                        # => '--opt'
      #   Configuration.longify(:opt, true)                  # => '--[no-]opt'
      #   Configuration.longify(:opt_ion)                    # => '--opt-ion'
      #   Configuration.longify(:opt_ion, false, false)      # => '--opt_ion'
      #
      #--
      # raise error if it does not begin with A-z, or contains =
      def longify(str, switch_notation=false, hyphenize=true)
        str = str.to_s
        str = "--#{str}" unless str.index("--")
        str.gsub!(/_/, '-') if hyphenize
        
        raise "invalid long option: #{str}" unless str =~ LONG_OPTION
        
        if switch_notation && $1.nil?
          str = "--[no-]#{$2}"
        end

        str
      end
    end
    
    include Utils
    
    attr_reader :long
    attr_reader :short
    attr_reader :desc     
    attr_reader :default  # the default value
    
    # number of times option may be specified.
    # nil indicates an option may be specified multiple times, each new value overrides the previous
    # 1 indicates a specification up to n times, collected as an array
    # -1 collects all values as a single array
    attr_reader :n        
    
    attr_reader :options  # an optional array of allowed values
    attr_reader :block    # values passed to block, if given.  result collected
    attr_reader :value
    
    attr_reader :nesting
    attr_reader :key
    
    NIL_VALUE = Object.new
      
    def initialize(name, default, attributes={}, &block)
      @long = longify(attributes[:long] || name)
      @short = shortify(attributes[:short])
      @desc = attributes[:desc]
      @default = default
      @n = attributes[:n]
      @options = attributes[:options]
      @block = block
      @value = NIL_VALUE  # nil is not ok as a value if config_parser is to allow non-string inputs in the argv.
      
      @nesting = @name.split(':')
      @key = @nesting.shift
    end
    
    def reset
      @value = NIL_VALUE
    end
    
    def has_value?
      @value != NIL_VALUE
    end
    
    def parse!(provided_value, argv)
      self.value = argv.shift
    end
    
    def value=(value)
      raise "NIL_VALUE is an unacceptable value" if value == NIL_VALUE
      
      if n == 1
        raise "already assigned a value to #{self}: #{@value.inspect}" if has_value?
        @value = value
      else
        @value = [] unless has_value?
        @value << value
        raise "too many assignments to #{self}" if n > -1 && @value.length > n
      end
    end
    
    def value(process=true)
      if process
        value = has_value? ? @value : default
        block ? block.call(value) : value
      else
        @value
      end
    end
    
    def to_s
      "#{short}, #{long} #{default_str}  #{desc}"
    end
    
    def type_str
      case arg_type
      when :optional 
        "#{long} [#{arg_name}]"
      when :switch 
        long(true)
      when :flag
        long
      when :list
        "#{long} a,b,c"
      when :mandatory, nil
        "#{long} #{arg_name}"
      else
        raise "unknown arg_type: #{arg_type}"
      end
    end
  end
end