class ConfigParser
  
  # A medly of methods used throughout the ConfigParser classes.
  module Utils
    module_function
    
    # The option break argument
    OPTION_BREAK = "--"

    # Matches a nested long option, with or without a value
    # (ex: '--opt', '--nested:opt', '--opt=value').  After 
    # the match:
    #
    #   $1:: the switch
    #   $2:: the value
    #
    LONG_OPTION = /^(--[A-z].*?)(?:=(.*))?$/

    # Matches a nested short option, with or without a value
    # (ex: '-o', '-n:o', '-o=value').  After the match:
    #
    #   $1:: the switch
    #   $2:: the value
    #
    SHORT_OPTION = /^(-[A-z](?::[A-z])*)(?:=(.*))?$/

    # Matches the alternate syntax for short options
    # (ex: '-n:ovalue', '-ovalue').  After the match:
    #
    #   $1:: the switch
    #   $2:: the value
    #
    ALT_SHORT_OPTION = /^(-[A-z](?::[A-z])*)(.+)$/
    
    # Turns the input string into a short-format option.  Raises
    # an error if the option does not match SHORT_OPTION.  Nils
    # are returned directly.
    #
    #   shortify("-o")         # => '-o'
    #   shortify(:o)           # => '-o'
    #
    def shortify(str)
      return nil if str == nil
  
      str = str.to_s
      str = "-#{str}" unless str[0] == ?-
      unless str =~ SHORT_OPTION && $2 == nil
        raise ArgumentError, "invalid short option: #{str}"
      end
      str
    end

    # Turns the input string into a long-format option.  Underscores
    # are converted to hyphens. Raises an error if the option does
    # not match LONG_OPTION.  Nils are returned directly.
    #
    #   longify("--opt")       # => '--opt'
    #   longify(:opt)          # => '--opt'
    #   longify(:opt_ion)      # => '--opt-ion'
    #
    def longify(str)
      return nil if str == nil
  
      str = str.to_s
      str = "--#{str}" unless str =~ /^--/
      str.gsub!(/_/, '-')
      unless str =~ LONG_OPTION && $2 == nil
        raise ArgumentError, "invalid long option: #{str}"
      end
      str
    end
    
    # Adds a prefix onto the last nested segment of a long option.
    #
    #   prefix_long("--opt", 'no-')         # => '--no-opt'
    #   prefix_long("--nested:opt", 'no-')  # => '--nested:no-opt'
    #
    def prefix_long(switch, prefix, split_char=':')
      switch = switch[2,switch.length-2] if switch =~ /^--/
      switch = switch.split(split_char)
      switch[-1] = "#{prefix}#{switch[-1]}"
      "--#{switch.join(':')}"
    end
    
    # Infers the default long using key and adds it to attributes.  Returns
    # attributes.
    #
    #   infer_long(:key, {})                      # => {:long => '--key'}
    #
    def infer_long(key, attributes)
      unless attributes.has_key?(:long)
        attributes[:long] = "--#{key}"
      end
      
      attributes
    end
    
    # Infers the default argname from attributes[:long] and sets it in
    # attributes.  Returns attributes.
    #
    #   infer_arg_name(:key, {:long => '--opt'})  # => {:long => '--opt', :arg_name => 'OPT'}
    #   infer_arg_name(:key, {})                  # => {:arg_name => 'KEY'}
    #
    def infer_arg_name(key, attributes)
      if attributes.has_key?(:arg_name)
        return attributes
      end
      
      if long = attributes[:long]
        long.to_s =~ /^(?:--)?(.*)$/
        attributes[:arg_name] = $1.upcase
      else
        attributes[:arg_name] = key.to_s.upcase
      end
      
      attributes
    end
    
    # Attributes:
    #
    #   :long      the long key ("--key") 
    #   :arg_name  the argument name ("KEY") 
    #
    def setup_option(key, attributes={})
      infer_long(key, attributes)
      infer_arg_name(key, attributes)
      
      lambda {|value| config[key] = value }
    end
    
    # Attributes:
    #
    #   :long      the long key ("--key") 
    #
    def setup_flag(key, default=true, attributes={})
      infer_long(key, attributes)
      
      lambda {config[key] = !default }
    end
    
    # Attributes:
    #
    #   :long      the long key ("--[no-]key") 
    #
    def setup_switch(key, default=true, attributes={})
      infer_long(key, attributes)
      
      if attributes[:long].to_s =~ /^(?:--)?(\[no-\])?(.*)$/ 
        attributes[:long] = "--[no-]#{$2}" unless $1
      end
      
      lambda {|value| config[key] = value }
    end
    
    # Attributes:
    #
    #   :long      the long key ("--key")
    #   :arg_name  the argument name ("KEY")
    #   :split     the split character
    #
    def setup_list(key, attributes={})
      infer_long(key, attributes)
      infer_arg_name(key, attributes)
      
      split = attributes[:split]
      n = attributes[:n]
      
      lambda do |value|
        array = (config[key] ||= [])
        array.concat(split ? value.split(split) : [value])
        if n && array.length > n
          raise "too many assignments: #{key.inspect}"
        end
      end
    end
  end
end