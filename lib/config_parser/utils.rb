class ConfigParser
  module Utils
    module_function
    
    # The option break argument
    OPTION_BREAK = "--"

    # Matches a nested long option, with or without a value
    # (ex: '--opt', '--nested:opt', '--opt=value').  After 
    # the match:
    #
    #   $1:: the switch
    #   $3:: the value
    #
    LONG_OPTION = /^(--[A-z].*?)(=(.*))?$/

    # Matches a nested short option, with or without a value
    # (ex: '-o', '-n:o', '-o=value').  After the match:
    #
    #   $1:: the switch
    #   $4:: the value
    #
    SHORT_OPTION = /^(-[A-z](:[A-z])*)(=(.*))?$/

    # Matches the alternate syntax for short options
    # (ex: '-n:ovalue', '-ovalue').  After the match:
    #
    #   $1:: the switch
    #   $3:: the value
    #
    ALT_SHORT_OPTION = /^(-[A-z](:[A-z])*)(.+)$/
    
    # Turns the input string into a short-format option.  Raises
    # an error if the option does not match SHORT_OPTION.  Nils
    # are returned directly.
    #
    #   ConfigParser.shortify("-o")         # => '-o'
    #   ConfigParser.shortify(:o)           # => '-o'
    #
    def shortify(str)
      return nil if str == nil
  
      str = str.to_s
      str = "-#{str}" unless str[0] == ?-
      unless str =~ SHORT_OPTION && $3 == nil
        raise ArgumentError, "invalid short option: #{str}"
      end
      str
    end

    # Turns the input string into a long-format option.  Underscores
    # are converted to hyphens. Raises an error if the option does
    # not match LONG_OPTION.  Nils are returned directly.
    #
    #   ConfigParser.longify("--opt")       # => '--opt'
    #   ConfigParser.longify(:opt)          # => '--opt'
    #   ConfigParser.longify(:opt_ion)      # => '--opt-ion'
    #
    def longify(str)
      return nil if str == nil
  
      str = str.to_s
      str = "--#{str}" unless str =~ /^--/
      str.gsub!(/_/, '-')
      unless str =~ LONG_OPTION && $3 == nil
        raise ArgumentError, "invalid long option: #{str}"
      end
      str
    end
    
    # Options:
    #
    #   :long      the long key ("--key") 
    #   :arg_name  the argument name ("KEY") 
    #
    def setup_option(key, options={})
      options[:long] ||= "--#{key}"
      options[:long].to_s =~ /^(--)?(.*)$/ 
      options[:arg_name] ||= $2.upcase
      
      lambda {|value| config[key] = value }
    end
    
    # Options:
    #
    #   :long      the long key ("--key") 
    #
    def setup_flag(key, default=true, options={})
      options[:long] ||= "--#{key}"
      
      lambda {config[key] = !default }
    end
    
    # Options:
    #
    #   :long      the long key ("--[no-]key") 
    #
    def setup_switch(key, default=true, options={})
      options[:long] ||= "--#{key}"
      options[:long].to_s =~ /^(--)?(\[no-\])?(.*)$/ 
      options[:long] = "--[no-]#{$3}" unless $2
      
      lambda {|value| config[key] = (value ? !default : default) }
    end
    
    # Options:
    #
    #   :long      the long key ("--key")
    #   :arg_name  the argument name ("KEY" or "A,B,C" for a comma split) 
    #   :split     the split character
    #
    def setup_list(key, options={})
      options[:long] ||= "--#{key}"
      
      if split = options[:split]
        options[:arg_name] ||= %w{A B C}.join(split)
      else
        options[:long].to_s =~ /^(--)?(.*)$/ 
        options[:arg_name] ||= $2.upcase
      end
      
      n = options[:n]
      
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