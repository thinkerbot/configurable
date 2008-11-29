class ConfigParser
  module Utils
    module_function
    OPTION_BREAK = "--"
    
    # Matches a short option
    SHORT_OPTION = /^(-[A-z])(=?(.+))?$/
    
    # Turns the input string into a short-format option.  Raises
    # an error if the option does not match SHORT_OPTION.  Nils
    # are returned directly.
    #
    #   Utils.shortify("-o")         # => '-o'
    #   Utils.shortify(:o)           # => '-o'
    #
    def shortify(str)
      return nil if str == nil
      
      str = str.to_s
      str = "-#{str}" unless str[0] == ?-
      unless str =~ ConfigParser::SHORT_OPTION && ($3 == nil || $3.empty?)
        raise ArgumentError, "invalid short option: #{str}"
      end
      str
    end
    
    # Matches a long option
    LONG_OPTION = /^(--[A-z].*?)(=(.*))?$/  # variants: /^--([^=].*?)(=(.*))?$/
    
    # Turns the input string into a long-format option.  Underscores
    # are converted to hyphens. Raises an error if the option does
    # not match LONG_OPTION.  Nils are returned directly.
    #
    #   Utils.longify("--opt")       # => '--opt'
    #   Utils.longify(:opt)          # => '--opt'
    #   Utils.longify(:opt_ion)      # => '--opt-ion'
    #
    def longify(str)
      return nil if str == nil
      
      str = str.to_s
      str = "--#{str}" unless str =~ /^--/
      str.gsub!(/_/, '-')
      unless str =~ ConfigParser::LONG_OPTION && ($3 == nil || $3.empty?)
        raise ArgumentError, "invalid long option: #{str}"
      end
      str
    end
    
    # Splits and nests compound keys of a hash.
    #
    #   nest('key' => 1, 'compound:key' => 2)
    #   # => {
    #   # 'key' => 1,
    #   # 'compound' => {'key' => 2}
    #   # }
    #
    # Nest does not do any consistency checking, so be aware that results will
    # be ambiguous for overlapping compound keys.
    #
    #   nest('key' => {}, 'key:overlap' => 'value')
    #   # =? {'key' => {}}
    #   # =? {'key' => {'overlap' => 'value'}}
    #
    def nest(hash, split_char=":")
      result = {}
      hash.each_pair do |compound_key, value|
        if compound_key.kind_of?(String)
          keys = compound_key.split(split_char)
          
          unless keys.length == 1
            nested_key = keys.pop
            nested_hash = keys.inject(result) {|target, key| target[key] ||= {}}
            nested_hash[nested_key] = value
            next
          end
        end
        
        result[compound_key] = value
      end
      
      result
    end
    
  end
end