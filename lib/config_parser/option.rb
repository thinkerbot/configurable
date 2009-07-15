require 'config_parser/utils'

class ConfigParser
  
  # Represents an option registered with ConfigParser.
  class Option
    
    # A format string used by to_s
    LINE_FORMAT = "%-36s %-43s"
    
    # The short switch mapping to self
    attr_reader :short 
    
    # The long switch mapping to self
    attr_reader :long
    
    # The argument name printed by to_s.  If arg_name
    # is nil, no value will be parsed for self.
    attr_reader :arg_name
    
    # The description printed by to_s
    attr_reader :desc
    
    # The block called when one of the switches mapping
    # to self is parse; block will receive the parsed
    # argument if arg_name is specified.
    attr_reader :block
    
    # Initializes a new Option using attribute values for :long, :short,
    # :arg_name, and :desc.  The long and short values are transformed 
    # using Utils.longify and Utils.shortify, meaning both bare strings
    # (ex 'opt', 'o') and full switches ('--opt', '-o') are valid.
    def initialize(attributes={}, &block)
      @short = Utils.shortify(attributes[:short])
      @long = Utils.longify(attributes[:long])
      @arg_name = attributes[:arg_name]
      @desc = attributes[:desc]
      @block = block
    end
    
    # Returns an array of non-nil switches mapping to self (ie [long, short]).
    def switches
      [long, short].compact
    end
    
    # Parse determines how an option is actually parsed from an argv.  Parse 
    # recieves the switch mapping to self for cases in which it affects the 
    # outcome (see Switch).  By default parse has two modes of action:
    #
    # ==== Argument-style option (arg_name is specified)
    #
    # If arg_name is set, then parse passes value to the block. If no value
    # is specified, the next argument in argv is used instead.  An error
    # is raised if no value can be found.
    #
    # ==== Flag-style option (no arg_name is specified)
    # 
    # In this case, parse simply calls the block.  If a non-nil value is
    # specified, parse raises an error.
    #
    def parse(switch, value, argv)
      if arg_name
        unless value
          raise "no value provided for: #{switch}" if argv.empty?
          value = argv.shift
        end
        block ? block.call(value) : value
      else
        raise "value specified for flag: #{switch}" if value
        block ? block.call : nil
      end
    end
    
    # Formats self as a help string for use on the command line.
    def to_s
      lines = Lazydoc::Utils.wrap(desc.to_s, 43)
      
      header =  "    #{short_str} #{long_str} #{arg_name}"
      header = header.length > 36 ? header.ljust(80) : (LINE_FORMAT % [header, lines.shift])
      
      if lines.empty?
        header
      else
        lines.collect! {|line| LINE_FORMAT % [nil, line] }
        "#{header}\n#{lines.join("\n")}"
      end
    end
    
    private
    
    # helper returning short formatted for to_s
    def short_str # :nodoc:
      short ? short + ',' : '   '
    end
    
    # helper returning long formatted for to_s
    def long_str # :nodoc:
      long
    end
  end
end