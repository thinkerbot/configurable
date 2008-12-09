require 'config_parser/option'
require 'config_parser/switch'

autoload(:Shellwords, 'shellwords')

# ConfigParser is the Configurable equivalent of OptionParser and uses a
# similar, simplified (see below) syntax to declare options.
#
#   opts = {}
#   psr = ConfigParser.new do |psr|
#     psr.on "-s", "--long LONG", "a standard option" do |value|
#       opts[:long] = value
#     end
#   
#     psr.on "--[no-]switch", "a switch" do |value|
#       opts[:switch] = value
#     end
#
#     psr.on "--flag", "a flag" do
#       # note: no value is parsed; the block 
#       # only executes if the flag is found
#       opts[:flag] = true
#     end
#   end
#
#   psr.parse("a b --long arg --switch --flag c")   # => ['a', 'b', 'c']
#   opts             # => {:long => 'arg', :switch => true, :flag => true}
#
# ConfigParser builds in this pattern of setting values in a hash as they
# occur, and adds the ability to specify default values.  The syntax is
# not quite as friendly as for ordinary options, but meshes well with
# Configurable classes:
#
#   psr = ConfigParser.new
#   psr.define(:key, 'default', :desc => 'a standard option')
#
#   psr.parse('a b --key option c')                 # => ['a', 'b', 'c']
#   psr.config                                      # => {:key => 'option'}
#
#   psr.parse('a b c')                              # => ['a', 'b', 'c']
#   psr.config                                      # => {:key => 'default'}
#
# And now directly from a Configurable class, an equivalent to the
# original example:
#
#   class ConfigClass
#     include Configurable
#
#     config :long, 'default', :short => 's'  # a standard option
#     config :switch, false, &c.switch        # a switch
#     config :flag, false, &c.flag            # a flag
#   end
#
#   psr = ConfigClass.parser
#
#   psr.parse("a b --long arg --switch --flag c")   # => ['a', 'b', 'c']
#   psr.config    # => {:long => 'arg', :switch => true, :flag => true}
#
#   psr.parse("a b --long=arg --no-switch c")       # => ['a', 'b', 'c']
#   psr.config    # => {:long => 'arg', :switch => false, :flag => false}
#
#   psr.parse("a b -sarg c")                        # => ['a', 'b', 'c']
#   psr.config    # => {:long => 'arg', :switch => false, :flag => false}
#
# As you might expect, the options for configurations become the options 
# for define. In configurations like :switch, the block implies the 
# {:type => :switch} option and the config is converted into a switch
# by ConfigParser.
#
# Use the to_s method to convert a ConfigParser into command line
# documentation:
#
#   "\nconfigurations:\n#{psr.to_s}"
#   # => %q{
#   # configurations:
#   #    -s, --long LONG    a standard option
#   #        --[no-]switch  a switch
#   #        --flag         a flag
#   # }
#
# ==== Simplifications
#
# Unlike OptionParser, ConfigParser.on does not support automatic conversion of
# values, gets rid of 'optional' argument for options, and only supports a 
# single description string.  Hence:
#
#   psr = ConfigParser.new
#  
#   # incorrect
#   psr.on("--delay N", Float, "Delay N seconds before executing") do |value
#   end
#
#   # correct
#   psr.on("--delay N", "Delay N seconds before executing") do |value|
#     value.to_f
#   end
#
#   # this is OK syntactically, but ALWAYS requires the
#   # argument and uses the LAST string as the description.
#   psr.on("-i", "--inplace [EXTENSION]",
#          "Edit ARGV files in place",
#          "  (make backup if EXTENSION supplied)")
#
class ConfigParser
  class << self
    # Splits and nests compound keys of a hash.
    #
    #   ConfigParser.nest('key' => 1, 'compound:key' => 2)
    #   # => {
    #   # 'key' => 1,
    #   # 'compound' => {'key' => 2}
    #   # }
    #
    # Nest does not do any consistency checking, so be aware that results will
    # be ambiguous for overlapping compound keys.
    #
    #   ConfigParser.nest('key' => {}, 'key:overlap' => 'value')
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
  
  include Utils

  # A hash of (switch, Option) pairs mapping switches to
  # options.
  attr_reader :switches
  
  attr_reader :config
  
  attr_reader :default_config

  def initialize
    @options = []
    @switches = {}
    @config = {}
    @default_config = {}
  
    yield(self) if block_given?
  end

  # Returns an array of options registered with self.
  def options
    @options.select do |opt|
      opt.kind_of?(Option)
    end
  end

  # Adds a separator string to self.
  def separator(str)
    @options << str
  end

  # Registers the option with self by adding opt to options and mapping
  # the opt switches. Raises an error for conflicting keys and switches.
  def register(opt)
    @options << opt unless @options.include?(opt)

    opt.switches.each do |switch|
      case @switches[switch]
      when opt then next
      when nil then @switches[switch] = opt
      else raise ArgumentError, "switch is already mapped to a different option: #{switch}"
      end
    end

    opt
  end

  # Defines and registers a config with self.
  def define(key, default_value=nil, options={})
    # check for conflicts and register
    if default_config.has_key?(key)
      raise ArgumentError, "already set by a different option: #{key.inspect}"
    end
    default_config[key] = default_value
    
    block = case options[:type]
    when :switch then setup_switch(key, default_value, options)
    when :flag   then setup_flag(key, default_value, options)
    when :list   then setup_list(key, options)
    when nil     then setup_option(key, options)
    when respond_to?("setup_#{options[:type]}")
      send("setup_#{options[:type]}", key, default_value, options)
    else 
      raise ArgumentError, "unsupported type: #{options[:type]}"
    end
    
    on(options, &block)
  end
  
  def on(*args, &block)
    options = args.last.kind_of?(Hash) ? args.pop : {}
    args.each do |arg|
      # split switch arguments... descriptions
      # still won't match as a switch even
      # after a split
      switch, arg_name = arg.split(' ', 2)
      
      # determine the kind of argument specified
      key = case switch
      when SHORT_OPTION then :short
      when LONG_OPTION  then :long
      else :desc
      end
      
      # check for conflicts
      if options[key]
        raise ArgumentError, "conflicting #{key} options: [#{options[key]}, #{arg}]"
      end
      
      # set the option
      case key
      when :long, :short
        options[key] = switch
        options[:arg_name] = arg_name.strip if arg_name
      else
        options[key] = arg.strip
      end
    end
    
    # check if the option is specifying a Switch
    klass = case
    when options[:long].to_s =~ /^--\[no-\](.*)$/ 
      options[:long] = "--#{$1}"
      Switch
    else 
      Option
    end
    
    # instantiate and register the new option
    register klass.new(options, &block) 
  end
  
  # Parse is non-destructive to argv.  If a string argv is provided, parse
  # splits it into an array using Shellwords.
  #
  def parse(argv=ARGV, config={})
    @config = config
    argv = argv.kind_of?(String) ? Shellwords.shellwords(argv) : argv.dup
    args = []
    
    while !argv.empty?
      arg = argv.shift
  
      # determine if the arg is an option
      unless arg.kind_of?(String) && arg[0] == ?-
        args << arg
        next
      end
      
      # add the remaining args and break
      # for the option break
      if arg == OPTION_BREAK
        args.concat(argv)
        break
      end
  
      # split the arg...
      # switch= $1
      # value = $4 || $3 (if arg matches SHORT_OPTION, value is $4 or $3 otherwise)
      arg =~ LONG_OPTION || arg =~ SHORT_OPTION || arg =~ ALT_SHORT_OPTION 
  
      # lookup the option
      unless option = @switches[$1]
        raise "unknown option: #{$1}"
      end
  
      option.parse($1, $4 || $3, argv)
    end
    
    default_config.each_pair do |key, default|
      config[key] = default unless config.has_key?(key)
    end
    
    args
  end
  
  # Same as parse, but removes parsed args from argv.
  def parse!(argv=ARGV, config={})
    argv.replace(parse(argv, config))
  end

  def to_s
    comments = @options.collect do |option|
      next unless option.respond_to?(:desc)
      option.desc.kind_of?(Lazydoc::Comment) ? option.desc : nil
    end.compact
    Lazydoc.resolve_comments(comments)
    
    @options.collect do |option|
      option.to_s.rstrip
    end.join("\n") + "\n"
  end
end